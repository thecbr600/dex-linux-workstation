#!/usr/bin/env python3
import http.client
import json
import os
import re
import signal
import socket
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import hmac
import secrets
from pathlib import Path
from urllib.parse import parse_qs, urlparse

MODEL_PATH = Path.home() / "models" / "dex-qwen3-4b-Q5_K_M.gguf"
LOG_PATH = Path.home() / "dex-agent" / "llama-server.log"
PROXY_HOST = "127.0.0.1"
PROXY_PORT = 8080
BACKEND_PORT = 8081
BIND_HOST = os.environ.get("DEX_BIND_HOST", "127.0.0.1")
TOKEN_PATH = Path.home() / "dex-agent" / ".trigger_token"


def get_trigger_token() -> str:
    env_tok = os.environ.get("DEX_TRIGGER_TOKEN", "").strip()
    if env_tok:
        return env_tok
    TOKEN_PATH.parent.mkdir(parents=True, exist_ok=True)
    if TOKEN_PATH.exists():
        tok = TOKEN_PATH.read_text(encoding="utf-8").strip()
        if tok:
            return tok
    tok = secrets.token_hex(16)
    TOKEN_PATH.write_text(tok + "\n", encoding="utf-8")
    os.chmod(TOKEN_PATH, 0o600)
    return tok


def notify_watch(title: str, content: str, notif_id: str = "dex-watch") -> None:
    cmd = ["termux-notification", "--id", notif_id, "--title", title, "--content", content[:500]]
    try:
        subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5, check=False)
    except Exception:
        pass

def _run_watch_ask(prompt: str) -> None:
    with manager.lock:
        manager.active_requests += 1
        manager.last_activity = time.monotonic()
    try:
        ok, msg = manager.ensure_running()
        if not ok:
            notify_watch("DeX AI Fehler", msg)
            return
        payload = json.dumps({
            "model": "dex-qwen3-4b",
            "messages": [
                {"role": "system", "content": "Antworte direkt in maximal zwei kurzen deutschen Saetzen ohne Markdown oder Denkprozess."},
                {"role": "user", "content": prompt},
            ],
            "chat_template_kwargs": {"enable_thinking": False},
            "max_tokens": 160,
        }).encode("utf-8")
        conn = http.client.HTTPConnection(PROXY_HOST, BACKEND_PORT, timeout=180)
        conn.request("POST", "/v1/chat/completions", body=payload, headers={"Content-Type": "application/json"})
        resp = conn.getresponse()
        data = json.loads(resp.read().decode("utf-8", errors="replace"))
        conn.close()
        raw_reply = data.get("choices", [{}])[0].get("message", {}).get("content", "")
        if "</think>" in raw_reply:
            raw_reply = raw_reply.split("</think>")[-1]
        reply = re.sub(r"<think>.*?</think>", "", raw_reply, flags=re.DOTALL).strip()
        notify_watch("DeX AI", reply or "Keine Antwort erhalten.")
    except Exception as exc:
        notify_watch("DeX AI Fehler", str(exc))
    finally:
        with manager.lock:
            manager.active_requests = max(0, manager.active_requests - 1)
            manager.last_activity = time.monotonic()


IDLE_TIMEOUT_SEC = 180      # Auto-Sleep nach 3 Min. Leerlauf
MIN_WAKE_RAM_MB = 3800      # Mindest-RAM zum Starten des Modells
CRITICAL_RAM_MB = 1024
RAM_WARN_MB = 1400
THERMAL_WARN_C = 82.0
THERMAL_RECOVER_C = 75.0
RAM_RECOVER_MB = 1900      # Not-Abschaltung vor Android LMK
THREADS = 6
CTX_SIZE = 8192


def get_mem_available_mb() -> int:
    try:
        with open("/proc/meminfo", "r", encoding="utf-8") as f:
            for line in f:
                if line.startswith("MemAvailable:"):
                    return int(line.split()[1]) // 1024
    except OSError:
        pass
    return 0


def get_vitals() -> dict:
    av = get_mem_available_mb()
    tot = 0
    try:
        for ln in open("/proc/meminfo"):
            if ln.startswith("MemTotal:"):
                tot = int(ln.split()[1]) // 1024
                break
    except OSError:
        pass
    ct, gt, bt = [], [], []
    tr = Path("/sys/class/thermal")
    if tr.is_dir():
        for z in tr.glob("thermal_zone*"):
            try:
                zt = (z / "type").read_text().strip().lower()
                raw = float((z / "temp").read_text().strip())
                tc = raw / 1000.0 if abs(raw) > 200 else raw
                if 15 <= tc < 95:
                    if "gpu" in zt: gt.append(tc)
                    elif any(k in zt for k in ("cpu", "cpuss", "apc")): ct.append(tc)
                    elif any(k in zt for k in ("bat", "bms")): bt.append(tc)
            except OSError:
                pass
    bp, bs, btemp = None, "unknown", (round(max(bt), 1) if bt else None)
    bd = Path("/sys/class/power_supply/battery")
    if bd.is_dir():
        try:
            bp = int((bd / "capacity").read_text().strip())
            bs = (bd / "status").read_text().strip()
            r = float((bd / "temp").read_text().strip())
            btemp = round(r / 10.0 if abs(r) > 150 else r, 1)
        except OSError:
            pass
    if bp is None:
        try:
            r = subprocess.run(["termux-battery-status"], capture_output=True, text=True, timeout=2)
            if r.returncode == 0 and r.stdout.strip():
                d = json.loads(r.stdout)
                bp, bs = d.get("percentage"), d.get("status", bs)
                if d.get("temperature") is not None: btemp = round(float(d["temperature"]), 1)
        except Exception:
            pass
    ide = False
    try:
        with socket.create_connection(("127.0.0.1", 8443), timeout=0.15): ide = True
    except OSError:
        pass
    return {"state": manager.status().get("state"), "ide": "running" if ide else "stopped", "mem_available_mb": av, "mem_total_mb": tot, "cpu_temp_c": round(max(ct), 1) if ct else None, "gpu_temp_c": round(max(gt), 1) if gt else None, "battery_pct": bp, "battery_temp_c": btemp, "battery_status": bs}


class LlamaManager:
    def __init__(self) -> None:
        self.proc: subprocess.Popen | None = None
        self.lock = threading.RLock()
        self.active_requests = 0
        self.last_activity = time.monotonic()
        self.state = "sleeping"

    def is_alive(self) -> bool:
        return self.proc is not None and self.proc.poll() is None

    def _wait_healthy(self, timeout: float = 30.0) -> bool:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if not self.is_alive():
                return False
            try:
                conn = http.client.HTTPConnection(PROXY_HOST, BACKEND_PORT, timeout=1.0)
                conn.request("GET", "/health")
                resp = conn.getresponse()
                resp.read()
                conn.close()
                if resp.status == 200:
                    return True
            except OSError:
                time.sleep(0.25)
        return False

    def ensure_running(self) -> tuple[bool, str]:
        with self.lock:
            self.last_activity = time.monotonic()
            if self.is_alive() and self.state == "ready":
                return True, "ready"

            avail = get_mem_available_mb()
            if avail < MIN_WAKE_RAM_MB:
                return False, f"insufficient_ram ({avail} MB < {MIN_WAKE_RAM_MB} MB)"

            if not MODEL_PATH.is_file():
                return False, f"model_missing ({MODEL_PATH})"

            self.state = "waking"
            log_file = open(LOG_PATH, "a", encoding="utf-8")
            self.proc = subprocess.Popen(
                [
                    "llama-server",
                    "-m", str(MODEL_PATH),
                    "--host", PROXY_HOST,
                    "--port", str(BACKEND_PORT),
                    "-c", str(CTX_SIZE),
                    "-t", str(THREADS), "-ngl", "99", "-fa", "on", "--reasoning-budget", "0", "--chat-template-kwargs", '{"enable_thinking": false}',
                ],
                stdout=log_file,
                stderr=subprocess.STDOUT,
                start_new_session=True,
            )

        if self._wait_healthy():
            with self.lock:
                self.state = "ready"
                self.last_activity = time.monotonic()
            return True, "ready"

        self.sleep("startup_failed")
        return False, "llama-server_startup_failed"

    def sleep(self, reason: str = "idle") -> None:
        with self.lock:
            if self.is_alive():
                try:
                    os.killpg(self.proc.pid, signal.SIGTERM)
                    self.proc.wait(timeout=4)
                except Exception:
                    try:
                        os.killpg(self.proc.pid, signal.SIGKILL)
                    except Exception:
                        pass
            self.proc = None
            self.state = "sleeping"
            print(f"[dex-daemon] llama-server asleep ({reason})", flush=True)

    def status(self) -> dict:
        with self.lock:
            alive = self.is_alive()
            if not alive:
                self.state = "sleeping"
            idle = int(time.monotonic() - self.last_activity) if alive else 0
            return {
                "state": self.state,
                "pid": self.proc.pid if alive else None,
                "active_requests": self.active_requests,
                "idle_seconds": idle,
                "idle_timeout": IDLE_TIMEOUT_SEC,
                "mem_available_mb": get_mem_available_mb(),
                "model": MODEL_PATH.name,
            }


manager = LlamaManager()


def watchdog_loop() -> None:
    lw, wa, lt, ta = 0.0, False, 0.0, False
    while True:
        time.sleep(2.0)
        av, now = get_mem_available_mb(), time.monotonic()
        if 0 < av < CRITICAL_RAM_MB and manager.is_alive():
            manager.sleep("critical_ram")
            notify_watch("DeX RAM Not-Stopp", f"Nur {av} MB frei - GPU gestoppt.")
            wa, lw = True, now
            continue
        if 0 < av < RAM_WARN_MB:
            if manager.is_alive() and manager.active_requests == 0:
                manager.sleep("ram_early_warning")
                notify_watch("DeX RAM Warnung", f"Nur {av} MB frei - KI in Standby.")
                wa, lw = True, now
            elif not wa or (now - lw) >= 300:
                notify_watch("DeX RAM Warnung", f"Nur {av} MB frei (KI: {manager.state}).")
                wa, lw = True, now
        elif av >= RAM_RECOVER_MB:
            wa = False
        v = get_vitals()
        tmax = max([t for t in (v.get("cpu_temp_c"), v.get("gpu_temp_c")) if t is not None], default=0.0)
        if tmax >= THERMAL_WARN_C:
            if not ta or (now - lt) >= 300:
                notify_watch("DeX Thermal Warnung", f"SoC warm: CPU {v['cpu_temp_c']}C | GPU {v['gpu_temp_c']}C")
                ta, lt = True, now
        elif tmax <= THERMAL_RECOVER_C:
            ta = False
        with manager.lock:
            if manager.is_alive() and manager.active_requests == 0 and (now - manager.last_activity) >= IDLE_TIMEOUT_SEC:
                manager.sleep("idle")

class DexProxyHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt: str, *args) -> None:
        pass

    def _send_json(self, code: int, payload: dict) -> None:
        raw = json.dumps(payload).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)
        self.wfile.flush()

    def _handle_trigger(self, method: str) -> None:
        parsed = urlparse(self.path)
        qs = parse_qs(parsed.query)
        length = int(self.headers.get("Content-Length", "0"))
        raw_body = self.rfile.read(length) if length > 0 else b""
        body_json = {}
        if raw_body:
            try:
                body_json = json.loads(raw_body.decode("utf-8"))
            except Exception:
                self._send_json(400, {"ok": False, "error": "invalid_json"})
                return

        token = (
            self.headers.get("X-Dex-Token", "").strip()
            or (qs.get("token", [""])[0]).strip()
            or str(body_json.get("token", "")).strip()
        )
        if not token or not hmac.compare_digest(token, get_trigger_token()):
            self._send_json(401, {"ok": False, "error": "unauthorized"})
            return

        action = (
            (qs.get("action", [""])[0]).strip()
            or str(body_json.get("action", "status")).strip()
        ) or "status"
        notify_flag = (
            (qs.get("notify", [""])[0]).strip()
            or str(body_json.get("notify", "")).strip()
        ) in ("1", "true", "yes")

        if action == "wake":
            ok, msg = manager.ensure_running()
            st = manager.status()
            if notify_flag:
                notify_watch("DeX AI", f"GPU bereit ({st.get('mem_available_mb')} MB frei)" if ok else msg)
            self._send_json(200 if ok else 503, {"ok": ok, "action": action, "detail": msg, **st})
            return

        if action == "sleep":
            manager.sleep("watch_trigger")
            st = manager.status()
            if notify_flag:
                notify_watch("DeX AI", f"Standby aktiv ({st.get('mem_available_mb')} MB frei)")
            self._send_json(200, {"ok": True, "action": action, **st})
            return

        if action in ("ide_start", "ide_stop"):
            subcmd = "start" if action == "ide_start" else "stop"
            ide_bin = str(Path.home() / "bin" / "dex-ide")
            res = subprocess.run([ide_bin, subcmd], capture_output=True, text=True, timeout=15, check=False)
            if notify_flag:
                notify_watch("DeX IDE", f"code-server: {subcmd}")
            self._send_json(200 if res.returncode == 0 else 500, {
                "ok": res.returncode == 0,
                "action": action,
                "output": res.stdout.strip(),
            })
            return

        if action == "ask":
            prompt = (
                (qs.get("prompt", [""])[0]).strip()
                or str(body_json.get("prompt", "")).strip()
            )
            if not prompt:
                self._send_json(400, {"ok": False, "error": "missing_prompt"})
                return
            threading.Thread(target=_run_watch_ask, args=(prompt,), daemon=True).start()
            self._send_json(202, {"ok": True, "action": "ask", "queued": True})
            return

        if action == "vitals":
            v = get_vitals()
            if notify_flag:
                msg = f"AI: {v['state']} | IDE: {v['ide']}\nRAM: {v['mem_available_mb']}/{v['mem_total_mb']} MB\nCPU: {v['cpu_temp_c']}C | GPU: {v['gpu_temp_c']}C\nAkku: {v['battery_pct']}% ({v['battery_temp_c']}C)"
                notify_watch("DeX Vitals", msg)
            self._send_json(200, {"ok": True, "action": "vitals", **v})
            return

        st = manager.status()
        if notify_flag:
            notify_watch("DeX Status", f"State: {st.get('state')} | RAM: {st.get('mem_available_mb')} MB")
        self._send_json(200, {"ok": True, "action": "status", **st})

    def _proxy(self, method: str) -> None:
        if self.path == "/dex/trigger" or self.path.startswith("/dex/trigger?"):
            self._handle_trigger(method)
            return
        if self.path == "/dex/status":
            self._send_json(200, manager.status())
            return
        if self.path == "/dex/vitals":
            self._send_json(200, get_vitals())
            return
        if self.path == "/dex/sleep":
            manager.sleep("manual")
            self._send_json(200, manager.status())
            return
        if self.path == "/dex/wake":
            ok, msg = manager.ensure_running()
            self._send_json(200 if ok else 503, {"ok": ok, "detail": msg, **manager.status()})
            return

        with manager.lock:
            manager.active_requests += 1
            manager.last_activity = time.monotonic()

        try:
            ok, msg = manager.ensure_running()
            if not ok:
                self._send_json(503, {"error": {"message": msg, "type": "dex_unavailable"}})
                return

            length = int(self.headers.get("Content-Length", "0"))
            body = self.rfile.read(length) if length > 0 else None

            fwd_headers = {
                k: v for k, v in self.headers.items()
                if k.lower() not in ("host", "connection", "transfer-encoding")
            }
            fwd_headers["Host"] = f"{PROXY_HOST}:{BACKEND_PORT}"

            conn = http.client.HTTPConnection(PROXY_HOST, BACKEND_PORT, timeout=300)
            conn.request(method, self.path, body=body, headers=fwd_headers)
            resp = conn.getresponse()

            self.send_response(resp.status, resp.reason)
            has_length = False
            for k, v in resp.getheaders():
                lk = k.lower()
                if lk in ("transfer-encoding", "connection"):
                    continue
                if lk == "content-length":
                    has_length = True
                self.send_header(k, v)

            if not has_length:
                self.send_header("Connection", "close")
                self.close_connection = True
            self.end_headers()

            while True:
                chunk = resp.read(2048 if not has_length else 16384)
                if not chunk:
                    break
                self.wfile.write(chunk)
                self.wfile.flush()
            conn.close()
        except Exception as exc:
            try:
                self._send_json(502, {"error": {"message": str(exc), "type": "dex_proxy_error"}})
            except OSError:
                pass
        finally:
            with manager.lock:
                manager.active_requests = max(0, manager.active_requests - 1)
                manager.last_activity = time.monotonic()

    def do_GET(self) -> None:
        self._proxy("GET")

    def do_POST(self) -> None:
        self._proxy("POST")


def shutdown_handler(signum, frame) -> None:
    manager.sleep("daemon_exit")
    sys.exit(0)


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, shutdown_handler)
    signal.signal(signal.SIGINT, shutdown_handler)
    threading.Thread(target=watchdog_loop, daemon=True).start()
    server = ThreadingHTTPServer((BIND_HOST, PROXY_PORT), DexProxyHandler)
    print(f"[dex-daemon] listening on http://{BIND_HOST}:{PROXY_PORT}", flush=True)
    server.serve_forever()

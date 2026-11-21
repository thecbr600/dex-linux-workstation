#!/usr/bin/env python3
import http.client
import json
import os
import signal
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

MODEL_PATH = Path.home() / "models" / "dex-qwen3-4b-Q5_K_M.gguf"
LOG_PATH = Path.home() / "dex-agent" / "llama-server.log"
PROXY_HOST = "127.0.0.1"
PROXY_PORT = 8080
BACKEND_PORT = 8081

IDLE_TIMEOUT_SEC = 180      # Auto-Sleep nach 3 Min. Leerlauf
MIN_WAKE_RAM_MB = 3800      # Mindest-RAM zum Starten des Modells
CRITICAL_RAM_MB = 1536      # Not-Abschaltung vor Android LMK
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
                    "-t", str(THREADS), "-ngl", "99", "-fa", "on", "--reasoning-budget", "0",
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
    while True:
        time.sleep(5)
        if not manager.is_alive():
            continue
        avail = get_mem_available_mb()
        if avail < CRITICAL_RAM_MB:
            manager.sleep(f"lmk_guard_{avail}MB")
            continue
        with manager.lock:
            idle = time.monotonic() - manager.last_activity
            busy = manager.active_requests > 0
        if not busy and idle >= IDLE_TIMEOUT_SEC:
            manager.sleep(f"idle_{int(idle)}s")


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

    def _proxy(self, method: str) -> None:
        if self.path == "/dex/status":
            self._send_json(200, manager.status())
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
    server = ThreadingHTTPServer((PROXY_HOST, PROXY_PORT), DexProxyHandler)
    print(f"[dex-daemon] listening on http://{PROXY_HOST}:{PROXY_PORT}", flush=True)
    server.serve_forever()

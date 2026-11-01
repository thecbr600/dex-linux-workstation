DeX Linux Workstation

Ein vollautomatisiertes, schlüsselfertiges Linux-System für Android (Samsung DeX, Tablets und Smartphones) auf Basis von Termux und PRoot.

🚀 Features

Turn-Key Setup: Installiert Debian 12 (Bookworm) mit XFCE4 in einem einzigen, automatisierten Durchlauf.

Hardware-Agnostisch: Unter Volllast getestet auf Qualcomm Snapdragon (z. B. S26 Ultra 16GB) und MediaTek Dimensity (z. B. Tab S10 Ultra 16GB).

Fehlerfreies Audio: Vorkonfigurierte PulseAudio-TCP-Bridge (Port 4713) für sofortige Tonwiedergabe ohne manuelles Routing.

Chromium Ready: Enterprise-Policies unterdrücken Banner-Meldungen dauerhaft, ohne Google- und YouTube-Logins zu beeinträchtigen.

Adaptive DPI: Dedizierte Startskripte für Desktop-Monitore/DeX und mobile Displays für perfekte Skalierung.

Robuster Start: Automatische Lockfile-Bereinigung vor jedem Start verhindert Socket-Konflikte und X11-Ghosting.

⚙️ Installation

Kopiere den folgenden Einzeiler und führe ihn in einem frischen Termux-Terminal aus:

curl -sL https://raw.githubusercontent.com/thecbr600/dex-linux-workstation/main/setup.sh | bash


Die Installation läuft vollautomatisch durch und dauert je nach Internetanbindung ca. 10 bis 15 Minuten.

🖥️ Nutzung

Nach erfolgreicher Installation startest du das System direkt aus dem Termux-Prompt:

Samsung DeX & externe Monitore:

./desktop

Tablets & Smartphones (skaliert Oberfläche und Schriftarten auf 240 DPI):

./mobile

🏗️ Architektur & Tech-Stack

Betriebssystem: Debian 12 (Bookworm) via proot-distro (rootless Userland).

Display-Server: Termux-X11 über native UNIX-Sockets (:0).

Desktop-Umgebung: XFCE4 im schlanken Standard-Layout (ohne fehlerhaftes Plank-Dock).

Audio-Routing: PulseAudio über eine vorkonfigurierte TCP-Loopback-Bridge (tcp:127.0.0.1:4713).

Grafik-Rendering: CPU / LLVMpipe als Multi-Core-optimierter Software-Rasterizer.

⚠️ Aktuelle Limitierungen (CPU-Rendering)

Dieses System läuft aus Stabilitätsgründen rein über CPU-Software-Rendering (LLVMpipe). Es ist als hochstabile Produktivitäts-Workstation (Software-Entwicklung, LibreOffice, GIMP, Web-Recherche, Terminal) konzipiert.

Da Android im ungerooteten Zustand den direkten GPU-Zugriff im PRoot-Container isoliert, ist dieses Setup aktuell nicht für 3D-Gaming oder 4K-Videobearbeitung gedacht.

🤝 Contributing & Ausblick (GPU-Beschleunigung)

Die Hardware-Beschleunigung (GPU Pass-through via VirGL, Turnip oder Zink) ist die nächste Grenze für Linux auf mobiler Hardware. Dieses Repository liefert das sterile, reproduzierbare Fundament dafür. Pull Requests, Tests auf weiteren Geräten und Beiträge zur experimentellen GPU-Anbindung sind ausdrücklich willkommen!

📄 Lizenz

Dieses Projekt ist unter der GNU General Public License v3.0 (GPL-3.0) lizenziert – freie Modifikation und Weitergabe bleiben dauerhaft garantiert.

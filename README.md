# Jellyfin Failover (Docker / SWAG / rsync)

## 🎯 Overview

This project provides a **practical failover solution for Jellyfin** running in Docker, designed for self-hosters who want reliability without complex HA infrastructure.

It synchronizes Jellyfin configuration and database from a **master server** to a **slave server**, and allows traffic to be redirected automatically using **SWAG**.

This is a **disaster recovery / failover setup**, not a real-time high-availability cluster.

---

## 🏗️ Architecture

Users
|
v
SWAG (Reverse Proxy)
|
+--> Jellyfin MASTER (Unraid)
|
+--> Jellyfin SLAVE (Docker, low-power host)


### Key points

- Media files are stored on **shared NFS storage**
- Jellyfin configuration is synchronized using **rsync over SSH**
- The slave server is always powered on for fast recovery
- Jellyfin is never running on both servers at the same time (no split-brain)

---

## ✨ Features

- Automated Jellyfin failover
- Safe stop/start of Docker containers
- Configuration & database synchronization
- ACL and extended attributes preserved
- SSH key-based authentication
- Rollback mechanism in case of error
- Lock file to prevent concurrent executions
- Dry-run support for safe testing
- Optional UI warning banner on Jellyfin login page

---

## ⚙️ Requirements

### Master server
- Linux (Unraid supported)
- Docker
- rsync
- SSH client

### Slave server
- Linux
- Docker & Docker Compose
- rsync
- SSH server

### General
- SWAG reverse proxy
- Shared media storage (NFS recommended)
- SSH key-based authentication between master and slave

---

## 🔐 Security Notes

- A dedicated SSH key is used for failover
- `BatchMode=yes` prevents password prompts
- Containers are explicitly stopped before sync
- Optional root rsync to preserve permissions and ACLs
- Rollback automatically restarts containers if an error occurs

⚠️ **This setup assumes a trusted local network**

---

## 🔁 Failover Workflow

1. Stop Jellyfin container on the master server
2. Stop Jellyfin container on the slave server (if running)
3. Synchronize Jellyfin configuration and database using rsync
4. Start Jellyfin container on the slave server
5. SWAG redirects traffic to the slave backend

If any step fails, a rollback is triggered and both containers are restarted.

---

## 🧪 Tests Before Production

Before using this setup in production, you **must** test the following:

- SSH connection without password
- rsync with `--dry-run`
- Correct exclusion of transcodes and cache
- Docker container stop/start behavior
- Rollback mechanism
- Slave Jellyfin startup with copied configuration
- Jellyfin database integrity
- SWAG routing to the slave server

A detailed checklist is available in `docs/tests.md`.

---

## 🎨 Jellyfin Login Warning (Backup Mode)

You can display a warning banner on the Jellyfin login page to inform users they are connected to a backup server.

This uses **separated HTML and CSS**, compatible with Jellyfin settings.

See `docs/jellyfin-ui.md`.

---

## 📂 Repository Structure

jellyfin-failover/
├── README.md
├── failover/
│ ├── jellyfin_failover.sh
│ └── jellyfin_failover.conf
├── docs/
│ ├── architecture.md
│ ├── tests.md
│ ├── failover.md
│ ├── failback.md
│ └── jellyfin-ui.md
├── LICENSE
└── COPYING


---

## ⚠️ Disclaimer

This project does **not** provide:
- Real-time replication
- Automatic failback
- Multi-master support

It is designed for **self-hosted environments** where simplicity, transparency, and control are preferred over complex orchestration systems.

Use at your own risk and test thoroughly.

---

## 🤝 Contributing

Contributions, suggestions, and feedback are welcome.

If you:
- improve the script
- adapt it to another setup
- add monitoring or automation
- find edge cases

Feel free to open an issue or pull request.

---

## 📜 License

This project is licensed under the  
**GNU General Public License v2.0**

See the `LICENSE` file for details.

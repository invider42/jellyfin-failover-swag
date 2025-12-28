# Installation Guide

This document describes how to install and configure the **Jellyfin failover setup** end-to-end, in a single place.

It covers:

* Installation of the failover script on **Unraid** using **CA User Scripts**
* SWAG reverse-proxy configuration
* Jellyfin slave UI warning configuration

---

## 1. Architecture Overview

* **Master server (Unraid)**

  * Jellyfin (Docker)
  * SWAG (Docker reverse proxy)
  * NFS server (media storage)
  * Failover script (CA User Scripts)

* **Slave server (Linux)**

  * Jellyfin (Docker)
  * NFS mount (media access)

The slave server is always powered on to allow fast failover.

---

## 2. Prerequisites

### Hardware

* 1 Unraid server (master)
* 1 Linux server (slave, low-power recommended)

### Software

On **both servers**:

* Docker
* rsync
* OpenSSH

⚠️ **Docker Jellyfin requirements (critical)**

The Jellyfin Docker container **must be identical on both servers**:

* Same Docker image (same repository and tag)
* Same volume mappings (config and media paths) or you need to update the failover script
* Same environment variables:

  * `PUID`
  * `PGID`
  * `UMASK`
* Same Jellyfin version

This ensures:

* Database compatibility
* Correct file permissions
* Safe rsync synchronization

On **master only**:

* Unraid
* CA User Scripts plugin
* NFS server enabled

---

## 3. Directory Layout

### Master (Unraid)

* Jellyfin config:

  * `/mnt/user/appdata/jellyfin/`
* Media storage (NFS export):

  * `/mnt/user/media/`

### Slave (Linux)

* Jellyfin config:

  * `/mnt/user/appdata/jellyfin/`
* Media storage (NFS export):

  * `/mnt/user/media/`

---

## 4. Jellyfin Installation (Master)

Install Jellyfin using Docker (LinuxServer image recommended).

Required mounts:

* Config: `/mnt/user/appdata/jellyfin`
* Media: `/mnt/user/media`

Expose port `8096`.

Verify Jellyfin works correctly before continuing.

---

## 5. Jellyfin Installation (Slave)

* Use **the same Docker image** as the master
* Config directory: `/mnt/user/appdata/jellyfin`
* Media mount: `/mnt/user/media` (NFS)

⚠️ Do **not** configure libraries manually on the slave.
All configuration will be synced from the master.

---

## 6. NFS Configuration

### On Master (Unraid)

* Enable NFS in Unraid settings
* Export `/mnt/user/media`
* Allow access from the slave server

### On Slave

* Mount the NFS share persistently (e.g. `/etc/fstab`)
* Verify read access only

---

## 7. SSH Passwordless Access

From the master:

1. Generate a dedicated SSH key for failover
2. Copy the public key to the slave
3. Verify passwordless login

This SSH key will be used by the failover script.

---

## 8. rsync Configuration

* Ensure `rsync` is installed on both servers
* Test with `--dry-run`
* Exclude transient directories:

  * `cache/`
  * `transcodes/`

---

## 9. Install the Failover Script on Unraid

### Using CA User Scripts

1. Install **CA User Scripts** from Community Applications

2. Create a new script named:
   `jellyfin_failover`

3. Paste the failover script into the editor

4. Adjust configuration variables:

   * Slave user
   * Slave IP
   * Paths
   * SSH key location

5. Set execution mode:

   * Manual (not recommand because slave will be in a late state in case of a fail)
   * Scheduled (cron) -> each day at night in my case

---

## 10. SWAG Configuration

This setup uses **NGINX upstream failover** inside SWAG.

SWAG runs as a Docker container on the **master server** and proxies Jellyfin to either:

- the local Jellyfin container (master)
- the remote Jellyfin container (slave) as a backup

---

### 10.1 Requirements

- Jellyfin container on the master **must be named **``
- Jellyfin must listen on port `8096`
- The slave Jellyfin must be reachable by IP (example: `192.168.0.2:8096`)
- Your DNS must contain a **CNAME** for Jellyfin (example: `jellyfin.example.com`)

In Jellyfin settings (both servers):

- Dashboard → Advanced → Networking
- Add your Jellyfin domain as a **known proxy**

---

### 10.2 NGINX Upstream Failover Configuration

Create or edit the Jellyfin SWAG config file:

```
/config/nginx/site-confs/jellyfin.conf
```

Use the following upstream-based failover configuration:

```
upstream jellyfin_upstream {
    server jellyfin:8096 fail_timeout=15s max_fails=3;
    server <SLAVE_IP>:8096 backup;
}
```

- The first server is the **master Jellyfin container**
- The second server is the **slave Jellyfin instance** marked as `backup`

NGINX will:

- Always use the master if available
- Automatically switch to the slave if the master stops responding

---

### 10.3 Proxy Configuration

Inside the `server` block, Jellyfin traffic is forwarded to the upstream:

```
proxy_pass http://jellyfin_upstream;
```

No URL change is required for clients.

---

### 10.4 Validation

Verify:

- Jellyfin is reachable when the master is running
- Jellyfin switches automatically when the master container is stopped
- SSL certificates remain valid
- No client-side reconfiguration is needed

---

## 11. Jellyfin Slave UI Warning

To avoid user confusion, configure a warning banner on the slave.

### HTML/CSS (Login Disclaimer)

* Jellyfin Dashboard → General → Branding
* Paste the custom HTML and CSS warning

This warning should clearly indicate:

* This is a backup server
* Performance may be reduced
* Data may not be fully up-to-date

---

## 12. Testing Before Production

Before enabling automation:

* Run all tests described in `tests.md`
* Validate rollback behavior
* Validate rsync integrity
* Validate SWAG routing

---

## 13. Go Live

Once everything is validated:

* Keep the slave server powered on
* Run failover script when needed
* Re-test after Jellyfin or Unraid updates

---

## Notes

This setup is **not real-time HA**.

It is designed for:

* Simplicity
* Reliability
* Easy recovery

Always test changes before production use.

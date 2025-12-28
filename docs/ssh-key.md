# SSH Key-based Authentication (Passwordless SSH)

For the failover script to work automatically, the master server must be able to SSH into the slave server **without entering a password**.

## Steps

### 1. Generate an SSH key on the master

```bash
ssh-keygen -t ed25519 -f ~/.ssh/jellyfin_failover -C "jellyfin failover key"
```

* Press Enter to accept the default location or specify a custom path
* **Do not enter a passphrase** (for unattended scripts)

### 2. Copy the public key to the slave

```bash
ssh-copy-id -i ~/.ssh/jellyfin_failover.pub user@slave_host
```

* Replace `user` with the SSH user on the slave
* Replace `slave_host` with the IP or hostname of the slave

### 3. Test the connection

```bash
ssh -i ~/.ssh/jellyfin_failover user@slave_host
```

* You should be able to log in **without entering a password**
* Optional: add `-o BatchMode=yes` in scripts to fail if password is required

### 4. Permissions check

Ensure the key files have correct permissions:

```bash
chmod 600 ~/.ssh/jellyfin_failover
chmod 644 ~/.ssh/jellyfin_failover.pub
```

## Notes

* This key should be **dedicated for failover only**
* Avoid using your personal SSH keys for automated scripts
* For security, consider restricting the key in `~/.ssh/authorized_keys` with `from="master_ip"` and/or `command="..."`

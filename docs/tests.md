## 1. SSH Connection

**Goal:** Ensure the master can connect to the slave without entering a password.

**Steps:**

1. Verify the SSH key exists on the master:
```bash
ls -l ~/.ssh/jellyfin_failover
```

2. Test passwordless connection:
```bash
ssh -i ~/.ssh/jellyfin_failover [YOUR_USER]@[SLAVE_IP]
```
- You should be able to log in without entering a password.

3. Optional: Test batch mode in scripts:
```bash
ssh -i ~/.ssh/jellyfin_failover -o BatchMode=yes [YOUR_USER]@[SLAVE_IP] "echo OK"
```

4. Verify key permissions:
```bash
chmod 600 ~/.ssh/jellyfin_failover
chmod 644 ~/.ssh/jellyfin_failover.pub
```

**Expected result:**  
- Connection succeeds without prompting for a password.  
- Key permissions are correct.


## 2. rsync Dry-Run

**Goal:** Ensure that configuration and database synchronization from master to slave works correctly without actually copying files.

**Steps:**

1. Run rsync in dry-run mode from the master:
```bash
rsync -avAX --dry-run
--delete
--exclude 'data/transcodes/'
--exclude 'cache/transcodes/'
--exclude 'branding.xml'
--exclude 'encoding.xml'
-e "ssh -i ~/.ssh/jellyfin_failover -o BatchMode=yes"
/mnt/user/appdata/jellyfin/ [YOUR_USER]@[SLAVE_IP]:/data/jellyfin/
```

2. Observe the output:

- Files that would be copied are listed.
- Excluded directories (`transcodes`) are skipped.
- No changes are made on the slave.

3. Optional: Test with `--itemize-changes` for detailed output:
```bash
rsync -av --dry-run --itemize-changes
-e "ssh -i ~/.ssh/jellyfin_failover -o BatchMode=yes"
/mnt/user/appdata/jellyfin/ [YOUR_USER]@[SLAVE_IP]:/data/jellyfin/
```

4. Verify that permissions and ACLs are correctly preserved.

**Expected result:**  

- Dry-run lists all files that would be synchronized.  
- No actual file changes on the slave.  
- Excluded directories are correctly skipped.  
- Permissions and ACLs are maintained.


## 3. Docker Containers

**Goal:** Verify that the Jellyfin containers on both master and slave servers can be stopped and started correctly.

**Steps:**

### Master Server

1. Stop the master Jellyfin container:
```bash
docker stop jellyfin
```

2. Check that the container has stopped:
```bash
docker ps --format '{{.Names}}'
```
- `jellyfin` should **not** appear in the list.

3. Start the master Jellyfin container:
```bash
docker start jellyfin
```

4. Verify that it is running:
```bash
docker ps --format '{{.Names}}'
```
- `jellyfin` should appear in the list.

### Slave Server (via Master)

1. Stop the slave Jellyfin container from the master:
```bash
ssh -i ~/.ssh/failover_key -o BatchMode=yes [YOUR_USER]@[SLAVE_IP] "docker stop jellyfin"
```

2. Check that the slave container has stopped:
```bash
ssh -i ~/.ssh/failover_key -o BatchMode=yes user@SLAVE_IP "docker ps --format '{{.Names}}'"
```
- `jellyfin` should **not** appear in the list.

3. Start the slave Jellyfin container from the master:
```bash
ssh -i ~/.ssh/failover_key -o BatchMode=yes user@SLAVE_IP "docker start jellyfin"
```

4. Verify that it is running:
```bash
ssh -i ~/.ssh/failover_key -o BatchMode=yes user@SLAVE_IP "docker ps --format '{{.Names}}'"
```

**Expected result:**  

- Both master and slave containers can be controlled from the master without errors.  
- Containers appear in `docker ps` only when running.




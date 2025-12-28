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
ssh -i ~/.ssh/failover_key -o BatchMode=yes [YOUR_USER]@[SLAVE_IP] "docker ps --format '{{.Names}}'"
```
- `jellyfin` should **not** appear in the list.

3. Start the slave Jellyfin container from the master:
```bash
ssh -i ~/.ssh/failover_key -o BatchMode=yes [YOUR_USER]@[SLAVE_IP] "docker start jellyfin"
```

4. Verify that it is running:
```bash
ssh -i ~/.ssh/failover_key -o BatchMode=yes [YOUR_USER]@[SLAVE_IP] "docker ps --format '{{.Names}}'"
```

**Expected result:**  

- Both master and slave containers can be controlled from the master without errors.  
- Containers appear in `docker ps` only when running.


## 4. Failover Script

**Goal:** Verify that the failover script properly stops the master, syncs configuration, and starts the slave.

**Steps:**

1. Make sure both master and slave containers are running.

2. Run the failover script from the master:
```bash
./jellyfin_failover.sh
```

3. Observe the output for any errors.

4. Verify master container is stopped:
```bash
docker ps --format '{{.Names}}'
```

- `jellyfin` should **not** appear on the master.

5. Verify slave container is running via SSH:
```bash
ssh -i ~/.ssh/failover_key -o BatchMode=yes user@SLAVE_IP "docker ps --format '{{.Names}}'"
```
- `jellyfin` should appear in the list.

6. Verify configuration and database have been synchronized:
```bash
ssh -i ~/.ssh/failover_key -o BatchMode=yes user@SLAVE_IP "ls -l /data/jellyfin"
```

- Key config files and folders should be present.

7. Test rollback (simulate an error):

- Temporarily make the slave directory unwritable or break the rsync command.
- Run the script.
- Verify that both master and slave containers are restarted automatically.

**Expected result:**  

- Failover script stops the master and starts the slave successfully.  
- Configuration and DB are synchronized.  
- Rollback works in case of errors, containers are running again.


## 5. Jellyfin Functionality

**Goal:** Ensure that Jellyfin works correctly on the slave server after failover.

**Steps:**

1. Access Jellyfin through the usual public URL (via SWAG).

2. Log in with an existing user account.

3. Verify that the media libraries are available:
- Movies, TV Shows, Music, etc. should be visible.
- No library should be missing.

4. Play several media files:
- Direct play
- Direct stream
- Transcoding (if applicable)

5. Verify metadata integrity:
- Posters and backgrounds are displayed
- Descriptions, seasons, and episodes are correct

6. Check user data:
- Watch history
- Continue watching
- Playlists
- Favorites

7. Verify that temporary data (transcodes, cache) is regenerated correctly if needed.

**Expected result:**

- Jellyfin is fully usable on the slave server.
- Media playback works as expected.
- User data and metadata are consistent.
- No visible database corruption or missing content.


## 6. SWAG / Reverse Proxy

**Goal:** Verify that SWAG correctly routes traffic to the active Jellyfin backend (master or slave).

**Steps:**

1. With the master Jellyfin container running:
- Access Jellyfin using the public URL.
- Verify that Jellyfin responds normally.

2. Stop the master Jellyfin container:

```bash
docker start jellyfin
```

5. Verify that SWAG continues to route traffic correctly according to your failover logic.

6. Check SWAG logs if needed:

```bash
docker logs swag
```

**Expected result:**

- Jellyfin is reachable through the same URL before and after failover.
- No manual change is required on the client side.
- SWAG properly switches backend based on availability.
- No SSL/TLS or routing errors are observed.

## 7. Optional UI Warning (Backup Mode)

**Goal:** Inform users that they are connected to a backup Jellyfin server.

**Steps:**

1. Ensure the custom HTML/CSS warning is configured in Jellyfin:
- Dashboard → General → Branding

2. Trigger a failover so that users are redirected to the slave server.

3. Access the Jellyfin login page.

4. Verify the warning message:
- Clearly states that this is a backup server
- Mentions possible reduced performance
- Mentions that some data may not be up-to-date


**Expected result:**

- Warning message is displayed only when connected to the slave server.
- Users clearly understand they are using a backup instance.
- No impact on login or playback functionality.

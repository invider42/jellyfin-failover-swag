#!/bin/bash
#
# Jellyfin Failover Script
# Copyright (C) 2025  <Your Name or Nickname>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1301, USA.
#
# ------------------------------------------------------------------
# Description:
# Automated failover script for Jellyfin running in Docker.
# Synchronizes configuration and database from a master server
# to a slave server using rsync over SSH, with rollback protection.
#
# Requirements:
# - Docker & Docker Compose
# - rsync
# - SSH key-based authentication
# - Shared media storage (NFS recommended)
#
# Author: invider42
# Repository: https://github.com/invider42/jellyfin-failover-swag
# License: GNU General Public License v2.0
# ------------------------------------------------------------------

set -euo pipefail

### CONFIG ###
SSH_OPTS="-i /root/.ssh/jellyfin_failover \
          -o BatchMode=yes \
          -o ConnectTimeout=5 \
          -o StrictHostKeyChecking=no \
          -o UserKnownHostsFile=/dev/null"

CONTAINER="jellyfin"
SLAVE_HOST="192.168.1.163"
SLAVE_USER="fufifu42"

CONFIG="/mnt/user/appdata/jellyfin/"

LOGFILE="/var/log/jellyfin_failover.log"
LOCKFILE="/tmp/jellyfin_failover.lock"
TIMEOUT=60

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOGFILE"
}

## Restart service in case of error
rollback() {
  log "ERREUR détectée — rollback en cours"

  log "Redémarrage Jellyfin master (si nécessaire)"
  docker start "$CONTAINER" || true

  log "Redémarrage Jellyfin slave (si nécessaire)"
  ssh $SSH_OPTS "$SLAVE_USER@$SLAVE_HOST" "docker start $CONTAINER || true"

  log "Rollback terminé"
}

trap rollback ERR


### LOCK ###
exec 9>"$LOCKFILE"
flock -n 9 || {
  log "Failover déjà en cours, sortie."
  exit 1
}

log "=== FAILOVER JELLYFIN ==="

### SANITY CHECK PATHS ###
[ -d "$CONFIG" ] || { log "ERREUR: CONFIG introuvable"; exit 1; }

ssh $SSH_OPTS "$SLAVE_USER@$SLAVE_HOST" \
  "[ -d '$CONFIG' ]" || { log "ERREUR: CONFIG introuvable"; exit 1; }

### STOP MASTER ###
if ! docker ps --format '{{.Names}}' | grep -q "^$CONTAINER$"; then
    log "Master déjà arrêté : arrêt du scipt car le serveur est peut-être en erreur et les données"
    exit 1
fi

log "Arrêt Jellyfin master"
docker stop "$CONTAINER"

log "Attente arrêt complet du master..."
for ((i=0;i<TIMEOUT;i++)); do
  if ! docker ps --format '{{.Names}}' | grep -q "^$CONTAINER$"; then
    log "Master arrêté"
    break
  fi
  sleep 1
done

if docker ps --format '{{.Names}}' | grep -q "^$CONTAINER$"; then
  log "ERREUR: le master ne s'est pas arrêté"
  false
fi

### STOP MASTER ###
log "Arrêt Jellyfin master"
docker stop "$CONTAINER"

### STOP SLAVE ###
log "Arrêt Jellyfin sur le slave (si actif)"
ssh $SSH_OPTS "$SLAVE_USER@$SLAVE_HOST" "docker stop $CONTAINER || true"

log "Attente arrêt complet du slave..."
for ((i=0;i<TIMEOUT;i++)); do
  if ! ssh $SSH_OPTS "$SLAVE_USER@$SLAVE_HOST" \
    "docker ps --format '{{.Names}}' | grep -q '^$CONTAINER$'"; then
    log "Slave arrêté"
    break
  fi
  sleep 1
done

if ssh $SSH_OPTS "$SLAVE_USER@$SLAVE_HOST" \
  "docker ps --format '{{.Names}}' | grep -q '^$CONTAINER$'"; then
  log "ERREUR: le slave ne s'est pas arrêté"
  false
fi

### SYNC ###
log "Synchronisation config Jellyfin"
rsync -avAX \
  --rsync-path="sudo rsync" \
  --numeric-ids \
  --delete \
  --exclude 'data/transcodes/' \
  --exclude 'cache/transcodes/' \
  --exclude 'log/' \
  --exclude 'branding.xml' \
  --exclude 'encoding.xml' \
  -e "ssh $SSH_OPTS" \
  "$CONFIG" \
  "$SLAVE_USER@$SLAVE_HOST:$CONFIG"

### RE START SLAVE ###
log "Démarrage Jellyfin master"
ssh $SSH_OPTS "$SLAVE_USER@$SLAVE_HOST" "docker start $CONTAINER"

### RE START MASTER ###
log "Démarrage Jellyfin master"
docker start "$CONTAINER"

trap - ERR
log "Failover Jellyfin terminé avec succès"

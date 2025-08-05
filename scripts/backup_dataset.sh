#!/usr/bin/env bash
set -euo pipefail

# Controleer of er exact 1 argument is (dataset naam)
if [ $# -ne 1 ]; then
  echo "Usage: $0 <dataset>" >&2
  exit 1
fi

DATASET="$1"
CONFIG="configs/${DATASET}.env"
LOGFILE="logs/${DATASET}.log"

# Controleer of de configuratie bestaat
if [ ! -f "$CONFIG" ]; then
  echo "❌ Config file $CONFIG not found" >&2
  exit 2
fi

# Zorg dat de log-map bestaat
mkdir -p logs

# Log alles naar zowel console als logfile
exec > >(tee -a "$LOGFILE") 2>&1

# Laad de environment-variabelen van de gekozen dataset
set -a
source "$CONFIG"
set +a

# Handige functie om tijd en context te loggen
info() {
  printf "\n[%s] %s: %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$DATASET" "$*"
}

info "🔐 Backup gestart voor dataset '$DATASET'"

# Maak het backup-archive aan
borg create \
  --verbose --stats --compression lz4 --exclude-caches \
  ::"{hostname}-${DATASET}-{now:%Y-%m-%d_%H:%M:%S}" \
  $BACKUP_PATHS

info "🧹 Verwijderen van oude backups (prune)"

# Prune oude backups volgens retentiebeleid
borg prune \
  --list --prefix "{hostname}-${DATASET}-" \
  --keep-daily "$PRUNE_KEEP_DAILY" \
  --keep-weekly "$PRUNE_KEEP_WEEKLY" \
  --keep-monthly "$PRUNE_KEEP_MONTHLY"

info "✅ Backup voor '$DATASET' voltooid"
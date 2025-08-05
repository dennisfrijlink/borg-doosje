<p align="center">
<img src="public/logo.png" width="160px" align="center">
</p>
<h1 align="center">BorgDoosje</h1>
<p align="center">
Een eenvoudig maar krachtig shellscript voor het beheren van **meerdere gescheiden Borg-backups**, elk met hun eigen configuratie, repository en wachtwoord. Inclusief logging per dataset.
</p>

---

## ✅ Features

- Meerdere datasets (zoals `photos`, `documents`, `projects`)
- Per dataset een eigen `.env` bestand met repo, paden en passphrase
- Logging per dataset
- Externe datasetlijst via `datasets.list` (dus geen hardcoded namen in scripts)
- Eenvoudig in te plannen via cron of systemd

---

## 📁 Bestandsstructuur

```
backup/
├── borg_dataset_backup.sh        # Hoofdscript per backup-config
├── run_all_backups.sh           # Voert alle backups uit op basis van datasets.list
├── datasets.list                # 🔧 Datasetnamen, buiten versiebeheer
├── configs/                     # Per-dataset configuratie
│   ├── photos.env
│   ├── documents.env
│   └── projects.env
└── logs/                        # Logbestanden per dataset
    ├── photos.log
    ├── documents.log
    └── projects.log
```

---

## 📜 1. Hoofdscript: `borg_dataset_backup.sh`

```bash
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
```

---

## 🧾 2. Voorbeeldconfiguraties (`configs/*.env`)

### `configs/photos.env`

```bash
export BORG_REPO='ssh://user@backup-server:/mnt/backups/photos'
export BORG_PASSPHRASE='SterkWachtwoordPhotos123'
export BACKUP_PATHS="/home/user/Pictures"
export PRUNE_KEEP_DAILY=7
export PRUNE_KEEP_WEEKLY=4
export PRUNE_KEEP_MONTHLY=6
```

### `configs/documents.env`

```bash
export BORG_REPO='ssh://user@backup-server:/mnt/backups/documents'
export BORG_PASSPHRASE='DocsBackupWachtwoord!'
export BACKUP_PATHS="/home/user/Documents /home/user/Work"
export PRUNE_KEEP_DAILY=5
export PRUNE_KEEP_WEEKLY=3
export PRUNE_KEEP_MONTHLY=6
```

### `configs/projects.env`

```bash
export BORG_REPO='ssh://user@backup-server:/mnt/backups/projects'
export BORG_PASSPHRASE='Project123!Backup'
export BACKUP_PATHS="/opt/code /srv/webapps"
export PRUNE_KEEP_DAILY=10
export PRUNE_KEEP_WEEKLY=4
export PRUNE_KEEP_MONTHLY=12
```

---

## 🔁 3. Alle backups runnen: `run_all_backups.sh`

```bash
#!/bin/bash
set -euo pipefail

mkdir -p logs

DATASET_FILE="datasets.list"

if [ ! -f "$DATASET_FILE" ]; then
  echo "❌ Bestand $DATASET_FILE niet gevonden"
  exit 1
fi

# Lees regels in array
mapfile -t DATASETS < "$DATASET_FILE"

for dataset in "${DATASETS[@]}"; do
  echo "📦 Start backup voor $dataset"
  ./borg_dataset_backup.sh "$dataset"
done
```

---

## 📄 4. Datasetlijst: `datasets.list`

> Dit bestand bevat de lijst van datasets die geback-upt moeten worden. Dit hoort **niet** in Git.

```
photos_local
photos_server1
photos_server2
documents
projects
```

Voeg dit bestand toe aan `.gitignore`.

---

## ✅ Gebruik

### Scripts uitvoerbaar maken:

```bash
chmod +x borg_dataset_backup.sh run_all_backups.sh
```

### Start één specifieke backup:

```bash
./borg_dataset_backup.sh documents
```

### Start alle backups (volgorde uit `datasets.list`):

```bash
./run_all_backups.sh
```

---

## 📂 Voorbeeld outputlog (`logs/photos.log`)

```
[2025-08-04 17:30:01] photos: 🔐 Backup gestart voor dataset 'photos'
------------------------------------------------------------------------------
Archive name: myhost-photos-2025-08-04_17:30:01
...
[2025-08-04 17:30:30] photos: 🧹 Verwijderen van oude backups (prune)
...
[2025-08-04 17:30:35] photos: ✅ Backup voor 'photos' voltooid
```

---

## 📅 Cron-voorbeeld

Voor dagelijkse backups om 03:00:

```cron
0 3 * * * /pad/naar/backup/run_all_backups.sh >> /var/log/borg_backups.log 2>&1
```

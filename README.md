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

## 📜 1. Hoofdscript: `backup_dataset.sh`

1. Valideert invoer (één argument: de datasetnaam).
2. Laadt een configuratiebestand dat bij die dataset hoort.
3. Maakt een backup via borg, een populair back-upprogramma.
4. Logt alles naar bestand én terminal.
5. Past retentie toe door oude backups op te schonen (prune).

```bash
#!/usr/bin/env bash

set -euo pipefail
# -e: Stop het script als een commando faalt
# -u: Stop als een ongedefinieerde variabele wordt gebruikt
# -o pipefail: Zorgt dat het script faalt als een commando in een pipe faalt

# Controleer of er precies 1 argument is meegegeven (de naam van de dataset)
if [ $# -ne 1 ]; then
  echo "Usage: $0 <dataset>" >&2  # $0 is de naam van het script zelf
  exit 1  # Foutcode 1 = verkeerd gebruik
fi

DATASET="$1"  # Het eerste (en enige) argument is de datasetnaam
CONFIG="configs/${DATASET}.env"  # Pad naar de config file voor deze dataset
LOGFILE="logs/${DATASET}.log"    # Pad naar de logfile voor deze dataset

# Controleer of de config file bestaat
if [ ! -f "$CONFIG" ]; then
  echo "❌ Config file $CONFIG not found" >&2  # >&2 stuurt output naar stderr
  exit 2  # Foutcode 2 = config niet gevonden
fi

# Zorg dat de logs directory bestaat (maakt deze aan indien nodig)
mkdir -p logs

# Stuur alle standaard output én fouten zowel naar console als naar logbestand
exec > >(tee -a "$LOGFILE") 2>&1
# 'tee -a' schrijft zowel naar stdout als naar het logbestand (append-modus)
# '2>&1' stuurt stderr naar stdout, zodat alles gelogd wordt

# Laad de environment-variabelen uit het .env bestand
set -a
source "$CONFIG"  # Voert het configbestand uit en laadt de variabelen
set +a
# 'set -a' zorgt dat alle gedefinieerde variabelen automatisch worden geëxporteerd

# Defineer een helper-functie om gelogde info-berichten te schrijven met timestamp
info() {
  printf "\n[%s] %s: %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$DATASET" "$*"
  # "$*" geeft alle argumenten mee aan de functie
}

# Begin van de backup, geef info-output
info "🔐 Backup gestart voor dataset '$DATASET'"

# Maak een backup-archive met borg
borg create \
  --verbose --stats --compression lz4 --exclude-caches \
  ::"{hostname}-${DATASET}-{now:%Y-%m-%d_%H:%M:%S}" \
  $BACKUP_PATHS
# --verbose: gedetailleerde output
# --stats: toon statistieken na afloop
# --compression lz4: gebruik lz4 compressie (snel, minder compact)
# --exclude-caches: sluit cache mappen uit
# Archive naam bevat hostname, datasetnaam en timestamp
# $BACKUP_PATHS moet in het .env bestand gedefinieerd zijn

info "🧹 Verwijderen van oude backups (prune)"

# Prune oude backups volgens een retentiebeleid
borg prune \
  --list --prefix "{hostname}-${DATASET}-" \
  --keep-daily "$PRUNE_KEEP_DAILY" \
  --keep-weekly "$PRUNE_KEEP_WEEKLY" \
  --keep-monthly "$PRUNE_KEEP_MONTHLY"
# Houdt een bepaald aantal dagelijkse, wekelijkse en maandelijkse backups bij
# Retentieparameters komen ook uit het .env bestand

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
# -e: Stop het script als een commando faalt
# -u: Stop als een ongedefinieerde variabele wordt gebruikt
# -o pipefail: Zorgt dat het script faalt als een commando in een pipe faalt

# Zorg dat de logs-map bestaat (voor het geval backup_dataset.sh logs schrijft)
mkdir -p logs

DATASET_FILE="datasets.list"  # Bestandsnaam met lijst van datasets (één per regel)

# Controleer of het bestand met datasets bestaat
if [ ! -f "$DATASET_FILE" ]; then
  echo "❌ Bestand $DATASET_FILE niet gevonden"
  exit 1  # Exit met foutcode 1 als het bestand ontbreekt
fi

# Lees alle regels uit het bestand in een array genaamd DATASETS
mapfile -t DATASETS < "$DATASET_FILE"
# mapfile leest het bestand regel voor regel en slaat het op in een bash array (-t verwijdert newline aan het einde van elke regel)

# Loop door elke dataset en start een backup
for dataset in "${DATASETS[@]}"; do
  echo "📦 Start backup voor $dataset"
  ./backup_dataset.sh "$dataset"
  # Roept het andere script aan (dat je eerder liet zien), met de datasetnaam als argument
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

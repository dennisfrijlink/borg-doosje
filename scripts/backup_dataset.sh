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

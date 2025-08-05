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

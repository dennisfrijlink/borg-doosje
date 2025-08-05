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
  ./backup_dataset.sh "$dataset"
done
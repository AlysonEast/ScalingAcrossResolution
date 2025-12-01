#!/bin/bash

### --- USER SETTINGS ---
PRODUCT="NAIP"
SITE="HARV"
export PRODUCT
export SITE

### --- AUTO-DETECT FILE COUNT ---
FILES=(../DeepForest/Outputs/${PRODUCT}/${SITE}/*.shp)
N=${#FILES[@]}

echo "Number of files: ${N}"

if [ "$N" -eq 0 ]; then
    echo "ERROR: No shapefiles found in ./Outputs/${PRODUCT}/${SITE}/"
    exit 1
fi

echo "Submitting array job for $N shapefiles..."

### --- SUBMIT SLURM ARRAY JOB ---
sbatch --array=1-$N GenerateDatasets_Slurm.sh


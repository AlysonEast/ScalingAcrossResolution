#!/bin/bash
#SBATCH --job-name=CrownsDataset
#SBATCH --time=6:00:00 #1 hour
#SBATCH --mail-type=ALL
#SBATCH --output=./outfiles/out_.%j
#SBATCH --account=PUOM0017


module purge
module load gcc/12.3.0
module load R/4.4.0
module load proj/9.2.1
module load gdal/3.7.3

Rscript GenerateDatasets.R

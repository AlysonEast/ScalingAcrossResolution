#!/bin/bash
#SBATCH --job-name=CrownsAlpha
#SBATCH --time=5:00:00 #
#SBATCH --mail-type=ALL
#SBATCH --output=./outfiles/out_%A_%a.out
#SBATCH --account=PUOM0017
#SBATCH --mem=64G

# Request NUMA-safe cores for parallel Stan
#SBATCH --cpus-per-task=1            # <<< choose your # of cores


# Total tiles = 438, chunk size = 50
# Number of array jobs = ceil(438/50) = 9
#SBATCH --array=1-9

module purge
module load gcc/12.3.0
module load R/4.4.0
module load proj/9.2.1
module load gdal/3.7.3

Rscript RecoverAlphaParallel.R 50

# Run R with number of internal threads
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
export R_STAN_NUM_THREADS=$SLURM_CPUS_PER_TASK

Rscript RecoverAlphaParallel.R $SLURM_ARRAY_TASK_ID 50 $SLURM_CPUS_PER_TASK

# Pass PRODUCT, SITE, and ARRAY_INDEX to R
#Rscript RecoverAlpha.R #"$SLURM_ARRAY_TASK_ID" "$PRODUCT" "$SITE"

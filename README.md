# ScalingAcrossResolutions

> **⚠️ DEVELOPMENT STATUS:** This repository is under active development. Currently operational for NAIP 30cm at HARV. NEON 10cm baseline analysis in progress.

## Overview

This repository performs Bayesian size-abundance analysis on tree crown segmentation outputs from the [Crown_Segmentation](../Crown_Segmentation) repository to validate their utility for recovering forest demographic relationships. Using the [ScalingFromSky](https://github.com/ForestScaling/ScalingFromSky) R package, we estimate two critical ecological parameters at 1-hectare resolution:

- **α (alpha)**: Power-law exponent describing the steepness of the size-abundance relationship
- **Ntot**: Total number of trees above a minimum size threshold

These parameters enable comparison of crown segmentation quality across data sources and assessment of resolution impacts on ecological inference.

---

## Repository Relationship

```
Crown_Segmentation 
    ├── Tree crown shapefiles (outputs)
    ├── CHM rasters (LiDAR)
    └── Site shapefiles (AOP extent, grids)
                ↓
ScalingAcrossResolutions
    ├── Crown dataset preparation
    ├── LAI data extraction
    ├── Bayesian parameter recovery
    └── Cross-product validation
```

**Input:** Crown segmentation shapefiles from Crown_Segmentation  
**Output:** Spatially explicit α and Ntot estimates for each imagery product at each site

---

## Current Status by Data Stream

| Site | Product | Resolution | Status | Priority |
|------|---------|-----------|--------|----------|
| HARV | NAIP | 30 cm | ✅ Operational | Complete |
| HARV | NEON (Weinstein) | 10 cm | 🔄 In Progress | **High - Baseline** |
| HARV | NAIP | 60 cm | 📋 Planned | Medium |
| HARV | MAXAR | ~30 cm | 📋 Planned | Low |
| BART | NAIP | 30 cm | 📋 Planned | Medium |
| BART | NEON | 10 cm | 📋 Planned | Medium |

Each data stream can be processed independently as crown segmentation outputs become available.

---

## Directory Structure

```
ScalingAcrossResolutions/
├── README.md
├── Old/                               # Archived scripts (pre-reorganization)
├── data_preparation/
│   ├── GenerateDatasetsIndv.R         # Process single shapefile → CSV with DBH
│   ├── GenerateDatasets_Batch.sh     # Auto-detect files, submit array job
│   ├── GenerateDatasets_Slurm.sh     # SLURM array job wrapper
│   └── ExtractGridLAI.R              # Extract LAI for each 1-ha grid cell
├── analysis/
│   ├── RecoverAlpha.R                # Serial parameter estimation (testing)
│   ├── RecoverAlphaParallel.R        # Parallel parameter estimation (production)
│   ├── Alpha_Slurm.sh                # SLURM array job (1 core/task)
│   └── Alpha_Slurm_multicore.sh      # SLURM array job (8 cores/task)
├── data/
│   ├── CrownDatasets/                # Crown datasets with DBH estimates
│   │   └── {SITE}_{PRODUCT}_trees_{TILE}.csv
│   ├── LAI/                          # Auxiliary LAI data
│   │   └── {SITE}_gridLAI.csv
│   └── NEON_LAI_download.R           # Download NEON LAI rasters
├── Results/
│   └── Parameters/
│       └── {SITE}/{PRODUCT}/
│           ├── Chunks/               # Chunk results from parallel processing
│           │   ├── {SITE}_{PRODUCT}_chunk{N}_alpha.csv
│           │   └── {SITE}_{PRODUCT}_chunk{N}_trees.csv
│           ├── alpha.csv             # Aggregated results (future)
│           └── ntot.csv              # Aggregated results (future)
└── outfiles/                         # SLURM output logs
    └── out_*.out
```

---

## Workflow

### Stage 1: Crown Dataset Preparation

Crown segmentation shapefiles from Crown_Segmentation are converted to analysis-ready CSV files with DBH estimates and 1-hectare grid assignments.

**Workflow execution:**

```bash
cd data_preparation

# Set variables for your data stream
export PRODUCT="NAIP"  # or "NEON", "MAXAR"
export SITE="HARV"     # or "BART"

# Auto-detect shapefiles and submit array job
bash GenerateDatasets_Batch.sh
```

**What happens:**
1. `GenerateDatasets_Batch.sh` counts shapefiles in `../Crown_Segmentation/Outputs/{PRODUCT}/{SITE}/`
2. Submits `GenerateDatasets_Slurm.sh` as array job (one task per shapefile)
3. Each task runs `GenerateDatasetsIndv.R` to process one tile:
   - Loads shapefile
   - Creates/loads 1-ha grid for site
   - Assigns each crown to grid cell (largest overlap)
   - Calculates crown area, perimeter, diameter
   - Extracts height from CHM
   - Estimates DBH using allometric equations
   - Saves: `data/CrownDatasets/{SITE}_{PRODUCT}_trees_{TILE}.csv`

**Script locations:**
- Main script: `data_preparation/GenerateDatasetsIndv.R`
- Batch wrapper: `data_preparation/GenerateDatasets_Batch.sh` (executes Slurm script)
- SLURM submission: `data_preparation/GenerateDatasets_Slurm.sh`

**Key parameters:**
- Working directory: `/fs/ess/PUOM0017/ForestScaling/DeepForest`
- Grid cell size: 100 m (1 hectare)
- CHM height filter: Trees with CHM < 3m excluded
- Allometric biome code: 0 (temperate)

**Outputs:**
- Crown datasets: `data/CrownDatasets/{SITE}_{PRODUCT}_trees_{TILE}.csv`
- Grid shapefile: `../Crown_Segmentation/Shapefiles/{SITE}_grid.shp`

---

### Stage 2: LAI Data Extraction

Extract mean Leaf Area Index (LAI) for each 1-hectare grid cell. LAI is used as an environmental covariate for Bayesian priors in parameter estimation.

**Execution:**

```bash
cd data_preparation

# Download NEON LAI rasters (if not already downloaded)
Rscript ../data/NEON_LAI_download.R

# Extract LAI for site
Rscript ExtractGridLAI.R
```

**What happens:**
1. Loads NEON LAI rasters (2019, 1m resolution)
2. For each NEON tile, mosaics neighboring tiles (handles edge grid cells)
3. Extracts mean LAI for each 1-ha grid cell
4. Saves: `data/LAI/{SITE}_gridLAI.csv`

**Note:** LAI extraction is **site-specific, not product-specific**. Run once per site, reuse for all products.

**Outputs:**
- LAI dataset: `data/LAI/{SITE}_gridLAI.csv`

---

### Stage 3: Bayesian Parameter Recovery

Estimate α and Ntot for each 1-hectare grid cell using the ScalingFromSky package.

#### Testing (Serial Processing)

```bash
cd analysis

# Edit RecoverAlpha.R to set product/site and test subset
Rscript RecoverAlpha.R
```

Use for initial testing on small subsets (hardcoded to process specific tiles currently).

#### Production (Parallel Processing)

```bash
cd analysis

# Option A: Array jobs (1 core per task)
# Good for: Initial runs, debugging, reprocessing failed cells
sbatch Alpha_Slurm.sh

# Option B: Multicore (8 cores per task)  
# Good for: Production runs with stable parameters
sbatch Alpha_Slurm_multicore.sh
```

**What happens:**
1. Loads all crown datasets for site/product
2. Loads LAI data
3. Divides grid cells into chunks (50 cells per chunk)
4. For each chunk (parallel via SLURM array):
   - For each grid cell with ≥75 crowns:
     - Runs kernel density estimation on DBH
     - Determines truncation breakpoint
     - Fits α using Stan (Bayesian MCMC)
     - Estimates Ntot integrating α uncertainty
5. Saves chunk results: `Results/Parameters/{SITE}/{PRODUCT}/Chunks/`

**Script details:**
- Main script: `analysis/RecoverAlphaParallel.R`
- SLURM submission: `analysis/Alpha_Slurm.sh` (1 core) or `Alpha_Slurm_multicore.sh` (8 cores)
- Working directory: `/fs/ess/PUOM0017/ForestScaling/ScalingAcrossResolution`

**Key parameters:**
- Chunk size: 50 grid cells per task
- Minimum crowns: 75 per grid cell
- Prior mean: 1.4 (LAI-informed)
- Prior SD: 0.3
- Stan chains: 4
- Stan iterations: 2000

**Outputs:**
- `Results/Parameters/{SITE}/{PRODUCT}/Chunks/{SITE}_{PRODUCT}_chunk{N}_alpha.csv`
- `Results/Parameters/{SITE}/{PRODUCT}/Chunks/{SITE}_{PRODUCT}_chunk{N}_trees.csv`

---

## Adding a New Data Stream

When Crown_Segmentation completes outputs for a new product:

```bash
# 1. Set environment variables
export PRODUCT="NEON"  # New product
export SITE="HARV"

# 2. Prepare crown datasets
cd data_preparation
bash GenerateDatasets_Batch.sh

# Wait for completion (~30-45 min for HARV)

# 3. Extract LAI (skip if already done for this site)
Rscript ExtractGridLAI.R

# 4. Estimate parameters
cd ../analysis
sbatch Alpha_Slurm_multicore.sh  # Or Alpha_Slurm.sh for array version

# Monitor progress
squeue -u $USER
tail outfiles/out_*.out

# 5. Results will be in Results/Parameters/{SITE}/{PRODUCT}/Chunks/
```

---

## NEON 10cm Baseline (Priority 1)

The NEON 10cm dataset (Weinstein et al. 2019) serves as the **baseline** for all comparisons.

**Why baseline:**
- Highest resolution (10 cm) captures more small trees
- Published validation against field data
- DeepForest was trained on this resolution
- Ground truth for validating other products

**Processing steps:**

```bash
export PRODUCT="NEON"
export SITE="HARV"

# Stage 1: Crown datasets
cd data_preparation
bash GenerateDatasets_Batch.sh

# Stage 2: LAI (if not done)
Rscript ExtractGridLAI.R

# Stage 3: Parameters (use multicore for baseline)
cd ../analysis
sbatch Alpha_Slurm_multicore.sh

# After completion, validate quality
# (validation scripts to be added)
```

---

## Script Execution Flow

### Crown Dataset Generation

```
GenerateDatasets_Batch.sh
    ├── Counts shapefiles in Crown_Segmentation/Outputs/
    ├── Sets PRODUCT and SITE environment variables
    └── Submits → GenerateDatasets_Slurm.sh (array job)
                      └── Runs → GenerateDatasetsIndv.R (per shapefile)
                                     ├── Loads shapefile
                                     ├── Assigns to grid
                                     ├── Calculates crown metrics
                                     ├── Extracts CHM height
                                     ├── Estimates DBH
                                     └── Saves CSV
```

### LAI Extraction

```
ExtractGridLAI.R (standalone)
    ├── Loads NEON LAI rasters
    ├── Mosaics tiles
    ├── Extracts mean LAI per grid cell
    └── Saves LAI dataset
```

### Parameter Estimation

```
Alpha_Slurm.sh (or Alpha_Slurm_multicore.sh)
    └── Runs → RecoverAlphaParallel.R (per chunk)
                   ├── Loads crown datasets
                   ├── Loads LAI data
                   ├── Processes assigned grid cells
                   │   ├── KDE on DBH
                   │   ├── Fit α (Stan)
                   │   └── Estimate Ntot
                   └── Saves chunk results
```

---

## Output File Formats

### Crown Datasets

**Location:** `data/CrownDatasets/{SITE}_{PRODUCT}_trees_{TILE}.csv`

**Columns:**
```
crown_id      : Unique crown identifier within tile
grid_id       : 1-hectare grid cell ID
image_path    : Source image filename
Area          : Crown area (m²)
Perimeter     : Crown perimeter (m)
Diameter      : Crown diameter (m)
Max_Height    : Maximum height from CHM (m)
DBH           : Estimated diameter at breast height (cm)
score         : Model confidence score
label         : Tree label (from segmentation)
```

### LAI Datasets

**Location:** `data/LAI/{SITE}_gridLAI.csv`

**Columns:**
```
grid_id    : 1-hectare grid cell ID
lai_val    : Mean LAI value
```

### Parameter Results (Chunks)

**Location:** `Results/Parameters/{SITE}/{PRODUCT}/Chunks/{SITE}_{PRODUCT}_chunk{N}_alpha.csv`

**Columns:**
```
variable    : Parameter name (alpha)
mean        : Posterior mean
median      : Posterior median
sd          : Standard deviation
mad         : Median absolute deviation
q5          : 5th percentile
q95         : 95th percentile
rhat        : Convergence diagnostic (< 1.1 good)
ess_bulk    : Effective sample size (bulk)
ess_tail    : Effective sample size (tail)
R2_kernel   : KDE fit quality
grid        : Grid cell ID
site        : Site code (HARV, BART)
```

Similar format for `_trees.csv` (Ntot estimates).

---

## Monitoring Jobs

```bash
# Check job status
squeue -u $USER

# Monitor in real-time
watch -n 30 'squeue -u $USER'

# Check specific job output
tail -f outfiles/out_JOBID_TASKID.out

# Count completed chunks
ls Results/Parameters/HARV/NAIP/Chunks/*.csv | wc -l

# Check for errors
grep -i error outfiles/out_*.out
```

---

## Troubleshooting

**"Not enough data to fit model"**
- Grid cells with <75 crowns are automatically skipped
- Expected for edge cells and sparse areas
- Not an error

**"No matching LAI values"**
- Ensure `ExtractGridLAI.R` completed successfully
- Check `data/LAI/{SITE}_gridLAI.csv` exists

**"Array index exceeds number of shapefiles"**
- `GenerateDatasets_Batch.sh` counts wrong number of files
- Check shapefiles exist in `../Crown_Segmentation/Outputs/{PRODUCT}/{SITE}/`

**"CHM raster not found"**
- CHM paths are hardcoded in `GenerateDatasetsIndv.R`
- Verify CHM rasters exist in `../Crown_Segmentation/LiDAR/NEON/`

**Stan convergence warnings (Rhat > 1.1)**
- Check individual grid cell diagnostics
- May need to adjust priors or increase iterations
- Acceptable for small percentage of cells

---

## Data Requirements

### From Crown_Segmentation
- Crown segmentation shapefiles: `../Crown_Segmentation/Outputs/{PRODUCT}/{SITE}/*.shp`
- Site shapefiles: `../Crown_Segmentation/Shapefiles/{SITE}_AOP.shp`
- CHM rasters: `../Crown_Segmentation/LiDAR/NEON/{SITE}/DP3.30015.001/.../CHM.tif`

### NEON Data Portal
- LAI rasters: DP3.30012.001 (2019)
- Download via: `data/NEON_LAI_download.R`

### Storage Requirements
- Crown datasets: ~500 MB per site
- LAI rasters: ~2 GB per site
- Results (chunks): ~50 MB per product per site

---

## Software Requirements

### R Packages
```r
# Core analysis
library(ScalingFromSky)  # GitHub or local install
library(sf)
library(dplyr)
library(rstan)
library(posterior)
library(VGAM)

# Spatial processing
library(terra)
library(raster)
library(itcSegment)

# NEON data access
library(neonUtilities)
library(neonOS)

# Optional (for parallel processing)
library(future)
library(future.apply)
```

### System Requirements
- R 4.4.0+
- SLURM scheduler
- GDAL 3.7.3
- PROJ 9.2.1

### HPC Modules (OSC)
```bash
module load gcc/12.3.0
module load R/4.4.0
module load proj/9.2.1
module load gdal/3.7.3
```

---

## Workflow Example: Complete Data Stream

Processing NAIP 30cm at HARV from start to finish:

```bash
# Navigate to repository
cd /fs/ess/PUOM0017/ForestScaling/ScalingAcrossResolution

# Set data stream
export PRODUCT="NAIP"
export SITE="HARV"

# Stage 1: Crown datasets (~30 min for HARV)
cd data_preparation
bash GenerateDatasets_Batch.sh

# Monitor
watch -n 30 'squeue -u $USER'

# Check progress
ls ../data/CrownDatasets/HARV_NAIP*.csv | wc -l

# Stage 2: LAI (skip if already done for HARV)
Rscript ExtractGridLAI.R
ls ../data/LAI/HARV_gridLAI.csv

# Stage 3: Parameters (~2-3 hours for HARV)
cd ../analysis
sbatch Alpha_Slurm_multicore.sh

# Monitor
tail -f ../outfiles/out_*.out

# Check results
ls ../Results/Parameters/HARV/NAIP/Chunks/*.csv | wc -l

# Stage 4: Aggregate results (script to be added)
# Rscript AggregateResults.R NAIP HARV
```

---

## Future Development

### Planned Features
- [ ] Result aggregation scripts (combine chunks)
- [ ] Cross-product comparison analysis
- [ ] Baseline validation scripts
- [ ] DBH distribution comparisons
- [ ] Spatial raster generation
- [ ] Visualization notebooks
- [ ] Quality control diagnostics

### Planned Data Streams
- [x] HARV - NAIP 30cm (complete)
- [ ] HARV - NEON 10cm (in progress - baseline)
- [ ] HARV - NAIP 60cm
- [ ] HARV - MAXAR 30cm
- [ ] BART - NEON 10cm
- [ ] BART - NAIP 30cm

---

## Scientific Background

### Size-Abundance Relationships

Remote sensing-based crown segmentation systematically underdetects small trees due to canopy occlusion. While field-measured size distributions follow a negative power law (many small trees, few large trees), remotely sensed data show truncated distributions.

**Our approach:**
1. Identify size threshold (xbreakpoint) where detection becomes reliable
2. Fit Pareto distribution to observable portion (DBH > xbreakpoint)
3. Use Bayesian methods to infer abundance of missing understory trees
4. Recover complete size-abundance relationships

**Parameters:**
- **α**: Describes steepness of size-abundance relationship (typical range: 1.3-1.6 for temperate forests)
- **Ntot**: Total tree abundance above minimum size (typical range: 300-600 trees/ha)

**Reference:** Eichenwald et al. (2025). Leveraging Remote Sensing and Theory to Predict Tree Size Abundance Distributions Across Space. *Global Ecology and Biogeography*, 34(8), e70085.

---

## Citation

If you use this workflow, please cite:

- **ScalingFromSky Package:** [Repository link]
- **Methodology:** Eichenwald et al. (2025)
- **DeepForest:** Weinstein et al. (2019)
- **NEON Baseline:** Weinstein et al. (2021)

---

## Contact

[Add contact information]

---

## License

[Add license information]

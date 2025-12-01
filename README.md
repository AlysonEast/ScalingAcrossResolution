# ScalingAcrossResolutions

> **⚠️ DEVELOPMENT STATUS:** This repository is under active development. Currently operational for NAIP 30cm at HARV. NEON 10cm baseline analysis in progress. BART site and MAXAR products planned for future integration.

## Overview

This repository performs Bayesian size-abundance analysis on tree crown segmentation outputs to validate their utility for recovering forest demographic relationships across different imagery sources and resolutions. Using the [ScalingFromSky](https://github.com/ForestScaling/ScalingFromSky) R package, we estimate two critical ecological parameters at 1-hectare resolution:

- **α (alpha)**: Power-law exponent describing the steepness of the size-abundance relationship
- **Ntot**: Total number of trees above a minimum size threshold

These parameters enable:
1. Comparison of crown segmentation quality across data sources
2. Assessment of resolution impacts on ecological inference
3. Validation of coarser imagery (NAIP, MAXAR) against NEON baseline

---

## Repository Relationship

```
Crown_Segmentation → ScalingAcrossResolutions
    ├── Tree crown shapefiles
    ├── Crown metrics (DBH, height, area)
    └── Grid cell assignments
                ↓
    ├── Bayesian parameter recovery
    ├── Cross-product comparisons
    └── Spatial validation
```

**Input:** CSV files from Crown_Segmentation containing tree-level metrics assigned to 1-hectare grid cells  
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
| BART | NEON (Weinstein) | 10 cm | 📋 Planned | Medium |

**Note:** Each data stream can be processed independently as crown segmentation outputs become available. The workflow is designed for incremental analysis.

---

## Conceptual Workflow

### Scientific Motivation

Remote sensing-based crown segmentation systematically underdetects small trees due to canopy occlusion. While field-measured size distributions follow a negative power law (many small trees, few large trees), remotely sensed data show truncated distributions. 

This workflow uses Bayesian methods to:
1. Identify the size threshold (xbreakpoint) above which trees are reliably detected
2. Fit a Pareto distribution to the observable portion
3. Infer the abundance of missing understory trees
4. Recover complete size-abundance relationships

### Workflow Stages

```
Stage 1: Data Preparation
├── Crown datasets from Crown_Segmentation
├── Grid cell assignments (1 hectare)
├── Extract auxiliary LAI data
└── Filter minimum crown thresholds

Stage 2: Bayesian Parameter Recovery
├── Kernel density estimation on DBH
├── Determine truncation breakpoint
├── Fit α using truncated Pareto + LAI prior
└── Estimate Ntot integrating uncertainty

Stage 3: Validation & Comparison
├── Compare to NEON 10cm baseline
├── Cross-product statistical tests
├── Generate spatial rasters
└── Validation figures
```

---

## Directory Structure

```
ScalingAcrossResolutions/
├── README.md                          # This file
├── WORKFLOW.md                        # Detailed execution guide
├── config/
│   ├── sites.yaml                     # Site parameters (UTM zones, paths)
│   ├── products.yaml                  # Product specifications
│   └── analysis_params.yaml           # Bayesian priors, thresholds
├── data_preparation/
│   ├── 01_prepare_crown_datasets.R    # Prep crown CSVs from shapefiles
│   ├── 02_extract_grid_lai.R          # Extract LAI for each grid cell
│   └── slurm/
│       ├── slurm_01_prepare_batch.sh  # Batch submission wrapper
│       └── slurm_01_prepare_array.sh  # Array job for parallel prep
├── analysis/
│   ├── 03_estimate_alpha_ntot.R       # Serial parameter estimation
│   ├── 03_estimate_alpha_ntot_parallel.R  # Parallel estimation
│   ├── 04_compare_across_products.R   # Statistical comparisons
│   ├── 05_spatial_validation.R        # Generate rasters, spatial analysis
│   ├── 06_validate_against_baseline.R # Compare to NEON 10cm
│   └── 07_dbh_distribution_comparison.R  # Distribution-level comparisons
├── slurm/
│   ├── slurm_03_alpha_array.sh        # Array jobs (1 core per task)
│   ├── slurm_03_alpha_multicore.sh    # Multicore jobs (8 cores per task)
│   └── logs/                          # SLURM output logs
├── data/
│   ├── crown_datasets/                # Input from Crown_Segmentation
│   │   ├── HARV/
│   │   │   ├── NAIP_30cm/
│   │   │   │   └── NAIP_30cm_HARV_7_{TILE}_trees.csv
│   │   │   ├── NEON_10cm/
│   │   │   │   └── NEON_10cm_HARV_7_{TILE}_trees.csv
│   │   │   ├── NAIP_60cm/
│   │   │   └── MAXAR_30cm/
│   │   └── BART/
│   │       ├── NAIP_30cm/
│   │       └── NEON_10cm/
│   ├── auxiliary/
│   │   └── lai/
│   │       ├── HARV_grid_lai.csv
│   │       └── BART_grid_lai.csv
│   └── reference/                     # Validation data
│       └── FIA/                       # For prior calibration
├── results/
│   ├── parameters/                    # Alpha and Ntot estimates
│   │   ├── HARV/
│   │   │   ├── NAIP_30cm/
│   │   │   │   ├── alpha.csv
│   │   │   │   ├── ntot.csv
│   │   │   │   ├── diagnostics.csv
│   │   │   │   └── chunks/           # Intermediate chunk results
│   │   │   └── NEON_10cm/            # **Baseline**
│   │   │       ├── alpha.csv
│   │   │       ├── ntot.csv
│   │   │       └── diagnostics.csv
│   │   └── BART/
│   ├── comparisons/                   # Cross-product analyses
│   │   ├── HARV_resolution_comparison.csv
│   │   ├── HARV_product_comparison.csv
│   │   └── HARV_vs_baseline_validation.csv
│   └── spatial/                       # Raster outputs (generated later)
│       ├── HARV_NAIP_30cm_alpha.tif
│       ├── HARV_NAIP_30cm_ntot.tif
│       ├── HARV_NEON_10cm_alpha.tif
│       └── HARV_NEON_10cm_ntot.tif
├── figures/
│   ├── distributions/                 # DBH distributions
│   ├── parameters/                    # Alpha/Ntot by product
│   ├── comparisons/                   # Cross-product plots
│   └── maps/                          # Spatial rasters
├── notebooks/                         # R Markdown for exploration
│   ├── 01_data_exploration.Rmd
│   ├── 02_parameter_diagnostics.Rmd
│   ├── 03_baseline_comparison.Rmd
│   └── 04_cross_product_comparison.Rmd
└── docs/
    ├── workflow_diagram.png
    ├── methodology.md
    └── troubleshooting.md
```

---

## Quick Start

### Prerequisites

**Software:**
- R 4.4.0+
- SLURM scheduler (for HPC execution)
- ScalingFromSky R package

**R Packages:**
```r
# Core analysis
install.packages("ScalingFromSky")  # From GitHub or local .tar.gz
install.packages(c("sf", "dplyr", "rstan", "posterior", "VGAM"))

# Spatial processing
install.packages(c("terra", "raster", "itcSegment"))

# Optional (for notebooks)
install.packages(c("ggplot2", "tidyr", "knitr", "rmarkdown"))
```

**Data:**
- Crown datasets from Crown_Segmentation (CSV format)
- NEON LAI data downloaded
- Site shapefiles (AOP extent, grid definitions)

### Configuration

Edit `config/sites.yaml` and `config/products.yaml` to match your local paths:

```yaml
# config/sites.yaml
HARV:
  name: "Harvard Forest"
  utm_zone: 32618
  crown_seg_path: "../Crown_Segmentation"
  aop_shapefile: "../Crown_Segmentation/Shapefiles/HARV_AOP.shp"
```

### Running a Complete Data Stream (Example: HARV NAIP 30cm)

**Step 1: Prepare Crown Datasets**
```bash
cd data_preparation/slurm
export PRODUCT="NAIP_30cm"
export SITE="HARV"
bash slurm_01_prepare_batch.sh
```

**Step 2: Extract LAI**
```bash
Rscript ../02_extract_grid_lai.R NAIP_30cm HARV
```

**Step 3: Estimate Parameters**
```bash
cd ../../slurm
# Option A: Array jobs (many small tasks)
sbatch slurm_03_alpha_array.sh NAIP_30cm HARV

# Option B: Multicore (fewer large tasks)
sbatch slurm_03_alpha_multicore.sh NAIP_30cm HARV
```

**Step 4: Aggregate Results**
```bash
cd ../analysis
Rscript 04_aggregate_results.R NAIP_30cm HARV
```

See [`WORKFLOW.md`](WORKFLOW.md) for detailed step-by-step instructions.

---

## Processing Strategy by Data Stream

### Current Priority: NEON 10cm Baseline (HARV)

The NEON 10cm dataset (Weinstein et al. 2019) serves as the **ground truth baseline** for all comparisons. Complete this first:

```bash
# 1. Prepare NEON crown datasets
export PRODUCT="NEON_10cm"
export SITE="HARV"
cd data_preparation/slurm
bash slurm_01_prepare_batch.sh

# 2. Extract LAI (if not already done)
cd ..
Rscript 02_extract_grid_lai.R NEON_10cm HARV

# 3. Estimate parameters (multicore recommended for baseline)
cd ../slurm
sbatch slurm_03_alpha_multicore.sh NEON_10cm HARV

# 4. Validate baseline quality
cd ../analysis
Rscript 08_validate_baseline_quality.R NEON_10cm HARV
```

### Incremental Addition of Data Streams

As new crown segmentation outputs become available from Crown_Segmentation:

**For each new product:**
1. Crown_Segmentation generates shapefiles → CSV datasets
2. Run data preparation (Steps 1-2 above) for that product
3. Run parameter estimation (Step 3) for that product
4. Compare to baseline (Step 4+)

**Example: Adding NAIP 60cm later**
```bash
export PRODUCT="NAIP_60cm"
export SITE="HARV"
# Run steps 1-3 independently
# Then compare to NEON_10cm baseline
Rscript analysis/06_validate_against_baseline.R NAIP_60cm HARV
```

---

## Data Preparation Details

### Stage 1: Crown Dataset Preparation

**Script:** `data_preparation/01_prepare_crown_datasets.R`

**Purpose:** Convert crown segmentation shapefiles to analysis-ready CSV files with:
- Grid cell assignments (1 hectare)
- Crown metrics (area, perimeter, diameter)
- Tree heights from CHM
- DBH estimates from allometric equations

**Input:**
- Shapefiles: `../Crown_Segmentation/Outputs/{PRODUCT}/{SITE}/*.shp`
- Grid shapefile: `../Crown_Segmentation/Shapefiles/{SITE}_grid.shp`
- CHM rasters: NEON LiDAR data

**Output:**
- `data/crown_datasets/{SITE}/{PRODUCT}/{PRODUCT}_{SITE}_{TILE}_trees.csv`

**Columns in output CSV:**
```
crown_id, grid_id, image_path, Area, Perimeter, Diameter, Max_Height, DBH
```

**Execution:**
```bash
# Single tile (for testing)
Rscript data_preparation/01_prepare_crown_datasets.R 1 NAIP_30cm HARV

# All tiles (parallel via SLURM array)
cd data_preparation/slurm
export PRODUCT="NAIP_30cm"
export SITE="HARV"
bash slurm_01_prepare_batch.sh
```

**Key Parameters:**
- `grid_cellsize`: 100 m (1 hectare)
- Minimum crown threshold: Configurable in `config/analysis_params.yaml`
- CHM height filter: Trees with CHM < 3m excluded

---

### Stage 2: LAI Extraction

**Script:** `data_preparation/02_extract_grid_lai.R`

**Purpose:** Extract mean Leaf Area Index (LAI) for each 1-hectare grid cell. LAI is used as an environmental covariate to inform Bayesian priors for α estimation.

**Input:**
- NEON LAI rasters: `DP3.30012.001` product
- Grid shapefile: `../Crown_Segmentation/Shapefiles/{SITE}_grid.shp`

**Output:**
- `data/auxiliary/lai/{SITE}_grid_lai.csv`

**Columns:**
```
grid_id, lai_val
```

**Execution:**
```bash
Rscript data_preparation/02_extract_grid_lai.R NAIP_30cm HARV
```

**Notes:**
- LAI extraction is site-specific, not product-specific
- Run once per site, reuse for all products at that site
- Handles tile mosaicking for grid cells at tile boundaries

---

## Analysis Details

### Stage 3: Bayesian Parameter Recovery

**Scripts:** 
- `analysis/03_estimate_alpha_ntot.R` (serial, for testing)
- `analysis/03_estimate_alpha_ntot_parallel.R` (production)

**Purpose:** Estimate α and Ntot for each 1-hectare grid cell using the ScalingFromSky package.

**Method:**

1. **Kernel Density Estimation (KDE):** Identify potential breakpoint (xbreakpoint) where size distribution transitions from truncated to theoretical
2. **Stage 1 - Estimate α:** Fit truncated Pareto distribution to DBH values above xbreakpoint using Bayesian inference with LAI-informed priors
3. **Stage 2 - Estimate Ntot:** Integrate uncertainty from Stage 1 to estimate total tree abundance

**Input:**
- Crown datasets: `data/crown_datasets/{SITE}/{PRODUCT}/*.csv`
- LAI data: `data/auxiliary/lai/{SITE}_grid_lai.csv`

**Output:**
- `results/parameters/{SITE}/{PRODUCT}/chunks/chunk_{N}_alpha.csv`
- `results/parameters/{SITE}/{PRODUCT}/chunks/chunk_{N}_ntot.csv`

**Execution:**

**Testing (single grid cell):**
```bash
Rscript analysis/03_estimate_alpha_ntot.R
# Edit script to specify PRODUCT, SITE, and grid_id
```

**Production (parallel):**
```bash
cd slurm

# Option A: Array jobs (recommended for initial testing)
# - 1 core per task
# - Good for debugging
# - Easy to restart failed tasks
sbatch slurm_03_alpha_array.sh NAIP_30cm HARV

# Option B: Multicore (recommended for production)
# - 8 cores per task
# - Faster overall
# - More efficient for large runs
sbatch slurm_03_alpha_multicore.sh NAIP_30cm HARV
```

**Parallel Processing Configuration:**

**Array Jobs:**
- Chunk size: 50 grid cells per task
- Total tasks: ceil(num_grids / 50)
- Memory: 64 GB per task
- Time: 5 hours per task
- **Use when:** Testing, debugging, or reprocessing failed cells

**Multicore:**
- Cores per task: 8
- Chunk size: 50 grid cells per task
- Memory: 64 GB per task
- Time: 5 hours per task
- **Use when:** Production runs with stable parameters

**Key Parameters** (in `config/analysis_params.yaml`):
```yaml
alpha_estimation:
  prior_mean: 1.4        # LAI-informed prior for α
  prior_sd: 0.3
  min_crowns: 75         # Minimum crowns per grid cell
  breakpoint_method: "kde"

ntot_estimation:
  integrate_alpha_uncertainty: true
```

---

### Stage 4: Result Aggregation

**Script:** `analysis/04_aggregate_results.R`

**Purpose:** Combine chunk results into final site/product-level parameter estimates.

**Input:**
- Chunk files: `results/parameters/{SITE}/{PRODUCT}/chunks/chunk_*_alpha.csv`

**Output:**
- `results/parameters/{SITE}/{PRODUCT}/alpha.csv` (all grid cells)
- `results/parameters/{SITE}/{PRODUCT}/ntot.csv` (all grid cells)
- `results/parameters/{SITE}/{PRODUCT}/diagnostics.csv` (convergence metrics)

**Execution:**
```bash
Rscript analysis/04_aggregate_results.R NAIP_30cm HARV
```

**Diagnostics Included:**
- Rhat (convergence diagnostic, should be < 1.1)
- Effective sample size (ESS)
- R² from KDE fit
- Number of crowns per grid cell

---

### Stage 5: Cross-Product Comparisons

**Script:** `analysis/05_compare_across_products.R`

**Purpose:** Statistical comparison of parameter estimates across imagery products.

**Input:**
- Parameter CSVs for multiple products at same site

**Output:**
- `results/comparisons/{SITE}_resolution_comparison.csv`
- `results/comparisons/{SITE}_product_comparison.csv`
- Comparison figures in `figures/comparisons/`

**Analyses:**
- ANOVA comparing α and Ntot across products
- Pairwise tests between products
- Effect size calculations
- Distribution comparisons

**Execution:**
```bash
Rscript analysis/05_compare_across_products.R HARV
```

---

### Stage 6: Baseline Validation

**Script:** `analysis/06_validate_against_baseline.R`

**Purpose:** Validate parameter recovery quality by comparing each product to NEON 10cm baseline.

**Input:**
- Baseline: `results/parameters/{SITE}/NEON_10cm/alpha.csv`
- Test product: `results/parameters/{SITE}/{PRODUCT}/alpha.csv`

**Output:**
- `results/comparisons/{SITE}_{PRODUCT}_vs_baseline.csv`
- Validation metrics: RMSE, bias, R², Pearson correlation
- Scatter plots and residual plots

**Execution:**
```bash
# Validate NAIP 30cm against baseline
Rscript analysis/06_validate_against_baseline.R NAIP_30cm HARV

# Validate all products at HARV against baseline
Rscript analysis/06_validate_against_baseline.R ALL HARV
```

**Key Validation Metrics:**
- **RMSE (Root Mean Square Error):** Overall prediction error
- **Bias:** Systematic over/underestimation
- **R²:** Proportion of variance explained
- **Spatial correlation:** How well spatial patterns are preserved

---

### Stage 7: DBH Distribution Comparisons

**Script:** `analysis/07_dbh_distribution_comparison.R`

**Purpose:** Compare DBH distributions between products to assess detection biases.

**Input:**
- Crown datasets: `data/crown_datasets/{SITE}/{PRODUCT}/*.csv`

**Output:**
- `results/comparisons/{SITE}_dbh_distributions.csv`
- Distribution plots in `figures/distributions/`

**Analyses:**
- Kolmogorov-Smirnov tests
- Median/quantile comparisons
- Detection rates by size class
- Truncation point identification

**Execution:**
```bash
Rscript analysis/07_dbh_distribution_comparison.R HARV
```

---

### Stage 8: Spatial Raster Generation

**Script:** `analysis/08_generate_spatial_rasters.R`

**Purpose:** Convert grid-based parameter estimates to continuous raster surfaces for spatial visualization and analysis.

**Input:**
- Parameter CSVs: `results/parameters/{SITE}/{PRODUCT}/alpha.csv`
- Grid shapefile: `../Crown_Segmentation/Shapefiles/{SITE}_grid.shp`

**Output:**
- `results/spatial/{SITE}_{PRODUCT}_alpha.tif`
- `results/spatial/{SITE}_{PRODUCT}_ntot.tif`

**Execution:**
```bash
# Generate rasters after parameter estimation is complete
Rscript analysis/08_generate_spatial_rasters.R NAIP_30cm HARV
```

**Note:** Raster generation happens AFTER parameter estimation for each data stream, not during.

---

## Troubleshooting

### Common Issues

**1. "Not enough crowns to fit model"**
```
Error: Grid cell X has only 45 crowns, minimum is 75
```
**Solution:** Grid cells with <75 crowns are skipped automatically. This is expected at forest edges. Adjust `min_crowns` in config if needed.

**2. "No matching LAI values"**
```
Error: No LAI data found for grid cell 123
```
**Solution:** Ensure `02_extract_grid_lai.R` completed successfully. Check LAI raster coverage matches AOP extent.

**3. Stan convergence warnings**
```
Warning: Rhat > 1.1 for parameter alpha
```
**Solution:** Check diagnostics.csv. High Rhat indicates poor convergence. May need more iterations or better priors.

**4. Missing CHM data**
```
Error: CHM raster not found for tile X
```
**Solution:** Verify NEON LiDAR data downloaded. Check paths in `config/sites.yaml`.

**5. SLURM job array exceeds limit**
```
Error: Array index exceeds number of files
```
**Solution:** Check number of shapefiles in Crown_Segmentation outputs. Batch script auto-detects count.

### Getting Help

1. Check `docs/troubleshooting.md` for detailed solutions
2. Review SLURM logs in `slurm/logs/`
3. Open an issue on GitHub with:
   - Product and site name
   - Error message
   - Relevant log files

---

## Data Stream Checklist

Use this checklist when adding a new product to the analysis:

### ✅ **NEON 10cm Baseline (HARV)** - Priority 1
- [ ] Crown datasets prepared
- [ ] LAI extracted
- [ ] Parameters estimated (alpha, Ntot)
- [ ] Results aggregated
- [ ] Quality validation performed
- [ ] Documented as baseline

### 📋 **NAIP 30cm (HARV)** - Complete
- [x] Crown datasets prepared
- [x] LAI extracted (reuse from NEON)
- [x] Parameters estimated
- [x] Results aggregated
- [x] Compared to baseline
- [x] Validated

### 📋 **NAIP 60cm (HARV)** - Future
- [ ] Crown segmentation complete (Crown_Segmentation)
- [ ] Crown datasets prepared
- [ ] LAI extracted (reuse)
- [ ] Parameters estimated
- [ ] Compared to baseline
- [ ] DBH distribution analysis

### 📋 **MAXAR 30cm (HARV)** - Future
- [ ] Crown segmentation complete (Crown_Segmentation)
- [ ] Crown datasets prepared
- [ ] LAI extracted (reuse)
- [ ] Parameters estimated
- [ ] Compared to baseline
- [ ] Multi-spectral band analysis

### 📋 **BART Site** - Future
- [ ] NEON 10cm baseline
- [ ] NAIP 30cm
- [ ] Cross-site comparison with HARV

---

## Output File Formats

### Parameter Estimates (alpha.csv, ntot.csv)

```csv
grid_id,variable,mean,median,sd,mad,q5,q95,rhat,ess_bulk,ess_tail,R2_kernel,site,product
1,alpha,1.42,1.41,0.08,0.07,1.29,1.56,1.01,2847,3012,0.94,HARV,NAIP_30cm
```

**Columns:**
- `grid_id`: 1-hectare grid cell identifier
- `variable`: Parameter name (alpha or N_tot)
- `mean`, `median`: Posterior summary statistics
- `sd`, `mad`: Standard deviation, median absolute deviation
- `q5`, `q95`: 5th and 95th percentiles (90% credible interval)
- `rhat`: Convergence diagnostic (< 1.1 is good)
- `ess_bulk`, `ess_tail`: Effective sample sizes
- `R2_kernel`: KDE fit quality
- `site`, `product`: Metadata

### Comparison Results

```csv
product,site,alpha_mean,alpha_sd,ntot_mean,ntot_sd,rmse_vs_baseline,bias_vs_baseline,r2_vs_baseline,n_grids
NAIP_30cm,HARV,1.45,0.12,487,156,0.08,-0.03,0.87,438
```

---

## Citation

If you use this workflow in your research, please cite:

- **ScalingFromSky Package:** [Repository link]
- **Methodology:** Eichenwald et al. (2025). Leveraging Remote Sensing and Theory to Predict Tree Size Abundance Distributions Across Space. *Global Ecology and Biogeography*, 34(8), e70085.
- **DeepForest:** Weinstein et al. (2019). Individual tree-crown detection in RGB imagery using semi-supervised deep learning neural networks. *Remote Sensing*, 11(11), 1309.

---

## Contributing

This is an active research project. We welcome:
- Bug reports and fixes
- Documentation improvements
- Suggestions for analysis workflows
- Extensions to new sites or products

Please open an issue or pull request on GitHub.

---

## License

[Add license information]

---

## Contact

[Add contact information]

---

## Acknowledgments

- NEON (National Ecological Observatory Network) for open data
- Ben Weinstein for DeepForest and NEON tree crown baseline
- ScalingFromSky package developers
- [Funding sources]

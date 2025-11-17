source(file.path(Sys.getenv("LMOD_PKG"), "init/R"))
module("load", "proj/9.2.1")
module("load", "gdal/3.7.3")

dyn.load("/apps/spack/0.21/pitzer/linux-rhel9-skylake/proj/gcc/12.3.0/9.2.1-buhooyr/lib64/libproj.so")
dyn.load("/apps/spack/0.21/pitzer/linux-rhel9-skylake/gdal/gcc/12.3.0/3.7.3-wmnbnyd/lib64/libgdal.so")

setwd("/fs/ess/PUOM0017/ForestScaling/DeepForest")

#install.packages("/users/PAS2136/alyeast/ScalingFromSky_0.0.0.9000.tar.gz", repos = NULL, type="source")

library(sf)
library(dplyr)
library(purrr)
library(stringr)
library(tibble)
library(ScalingFromSky)
library(terra)
library(itcSegment)
library(raster)

#product<-"NAIP"
#site<-"HARV"

args <- commandArgs(trailingOnly = TRUE)

task_id <- as.numeric(args[1])
product <- args[2]
site <- args[3]

cat("Task ID:", task_id, "\n")
cat("Product:", product, "\n")
cat("Site:", site, "\n")

#### Make 1ha Processing Grid ####
cat("Reading AOP extent...\n")
AOP<-st_read(paste0("./Shapefiles/",site,"_AOP.shp"))%>%
  st_transform(5070)

grid <- st_make_grid(AOP, cellsize = 100, square = TRUE)
#plot(grid)
#plot(AOP, add=TRUE)

grid <- st_intersection(AOP, grid)
#plot(grid)
grid$grid_id<-1:nrow(grid)

cat("Grid created with", nrow(grid), "cells.\n")

#### Process shape files to have information for Size-Abundance Scaling
files <- list.files(paste0("./Outputs/", product, "/", site, "/"),
                    pattern = "\\.shp$", full.names = TRUE)

if (task_id > length(files)) {
    stop("Array index exceeds number of shapefiles")
}
i <- task_id
file <- files[i]
cat("Processing file:", file, "\n")

# Prepare a results dataframe
crowns_assigned_df <- data.frame()

crowns<-st_read(paste0(file))
if (nrow(crowns) == 0) {
   cat("   -> No crowns found; skipping.\n")
  q("no")
}

crowns$crown_id<-1:nrow(crowns)
#plot(crowns)
grid<-st_transform(grid, st_crs(crowns))
  
# 2. Compute intersections
intersections <- st_intersection(crowns, grid)
  
if (nrow(intersections) == 0) {
  cat("   -> No intersections found; skipping.\n")
  q("no")
}
  
# 3. Calculate overlap area
print("3.")
intersections <- intersections %>%
  mutate(overlap_area = as.numeric(st_area(.)))
  
# 4. For each crown, find the grid cell with the largest overlap
print("4.")
assignment <- intersections %>%
  group_by(crown_id) %>%
  slice_max(overlap_area, n = 1, with_ties = FALSE) %>%
  ungroup() 
  
# 5. Join back to crowns
crowns <- left_join(crowns, as.data.frame(assignment)[,c("crown_id","grid_id")], by = "crown_id")
  
####Take area, perimeter, and Heights ####
crowns$Area <- as.numeric(st_area(crowns))
crowns$Perimeter <- as.numeric(st_perimeter(crowns))
crowns$Diameter<-0.5*(sqrt((crowns$Perimeter^2)-(8*crowns$Area)))
  
#### Prepare and Extract CHM ####
cat("Loading CHM raster...\n")
chm_dir_start<-"./LiDAR/NEON/HARV/DP3.30015.001/neon-aop-products/2022/FullSite/D01/"
dirs <- list.dirs(chm_dir_start, recursive = TRUE, full.names = TRUE)
  
# Split by "/", extract last two levels, and test if next-level contains "HARV"
dirs <- dirs[
  grepl("HARV", basename(dirname(dirs)))  # parent directory contains HARV
] 
dirs[1]
  
chm<-raster(paste0(dirs[1],"/DiscreteLidar/CanopyHeightModelGtif/NEON_D01_",
                   site,"_DP3_",
                   substr(file, (nchar(file)-17), (nchar(file)-4)),"_CHM.tif"))
crowns$Max_Height <- raster::extract(chm, crowns, fun=max, na.rm=TRUE)
  
### DBH Calculation ####
crowns$DBH<-dbh(H=crowns$Max_Height, CA=crowns$Diameter, biome = 0)

df<-as.data.frame(crowns)
crowns_assigned_df <- rbind(crowns_assigned_df, df)

#### Final save ####
out_file <- paste0("../ScalingAcrossResolution/CrownDatasets/",
                   site, "_", product, "_trees_", 
                   substr(file, (nchar(file)-17), (nchar(file)-4)),
                   ".csv")
write.csv(crowns_assigned_df, out_file, row.names = FALSE)
cat("Final dataset written to", out_file, "\n")

source(file.path(Sys.getenv("LMOD_PKG"), "init/R"))
module("load", "proj/9.2.1")
module("load", "gdal/3.7.3")

dyn.load("/apps/spack/0.21/pitzer/linux-rhel9-skylake/proj/gcc/12.3.0/9.2.1-buhooyr/lib64/libproj.so")
dyn.load("/apps/spack/0.21/pitzer/linux-rhel9-skylake/gdal/gcc/12.3.0/3.7.3-wmnbnyd/lib64/libgdal.so")

library(sf)
library(dplyr)
library(purrr)
library(stringr)
library(terra)
library(raster)

args <- commandArgs(trailingOnly = TRUE)

product <- "NAIP"#args[1]
site <- "HARV"#args[2]

cat("Product:", product, "\n")
cat("Site:", site, "\n")

setwd("/fs/ess/PUOM0017/ForestScaling/DeepForest")

#### Make 1ha Processing Grid ####
cat("Reading AOP extent...\n")
AOP<-st_read(paste0("./Shapefiles/",site,"_AOP.shp"))%>%
  st_transform(5070)

grid <- st_make_grid(AOP, cellsize = 100, square = TRUE)
grid <- st_sf(data.frame(grid_id=1:length(grid)), geometry = grid)
grid <- st_intersection(AOP, grid)
grid_dissolve <- grid %>% 
  group_by(grid_id) %>% 
  summarise(geometry = st_union(geometry))
grid_dissolve <- st_make_valid(grid_dissolve)
table(duplicated(grid_dissolve$grid_id))


# file_list<-list.files(path = "../ScalingAcrossResolution/CrownDatasets/", pattern = paste0(site,"_",product), full.names=TRUE)
# data_list <- lapply(file_list, read.csv)
# combined_data <- do.call(rbind, data_list)

Tiles<-AOP$TileID
LAI_df <- data.frame()

# Process each tile separately
for (i in 1:length(Tiles)) {
  tile<-Tiles[i]
  print(paste("Processing",i,"of",length(Tiles),":",tile))
  prefix<-substr(tile, 1, (nchar(tile)-14))
  tile.x<-as.numeric(substr(tile, (nchar(tile)-13), (nchar(tile)-8)))
  tile.y<-as.numeric(substr(tile, (nchar(tile)-6), nchar(tile)))
  
  #Fine neighboring tiles for grid cells that are on in the
  neighbors<-c(paste0(tile.x,"_",tile.y),
               paste0((tile.x-1000),"_",tile.y),
               paste0((tile.x+1000),"_",tile.y),
               paste0(tile.x,"_",(tile.y-1000)),
               paste0(tile.x,"_",(tile.y+1000)),
               paste0((tile.x-1000),"_",(tile.y-1000)),
               paste0((tile.x-1000),"_",(tile.y+1000)),
               paste0((tile.x+1000),"_",(tile.y-1000)),
               paste0((tile.x+1000),"_",(tile.y+1000)))
  
  #Read in LAI for all available neighbors tiles
  cat("Loading LAI raster...\n")
  lai_dir_start<-paste0("./Imagery/NEON/DP3.30012.001/neon-aop-products/2019/FullSite/D01/")
  dirs <- list.dirs(lai_dir_start, recursive = TRUE, full.names = TRUE)
  
  # Split by "/", extract last two levels, and test if next-level contains "HARV"
  dirs <- dirs[
    grepl(site, basename(dirname(dirs)))  # parent directory contains HARV
  ] 
  dirs[1]
  lai_dir<-paste0(dirs[1],"/Spectrometer/LAI/")
  
  all_lai<-list.files(lai_dir, pattern = "*_LAI.tif", full.names = TRUE)
  
  lai_avail<-all_lai[grepl(paste(neighbors, collapse = "|"), all_lai) ]
  
  cat("mosaic LAI raster...\n")
  if (length(lai_avail) > 1) {
    ras_list <- lapply(lai_avail, rast)
    merged_raster <- do.call(mosaic, c(ras_list, list(fun = mean)))
  } else {
    merged_raster <- rast(lai_avail[[1]])
  }
  
  if (length(lai_avail) == 0) {
    print(paste("No matching rasters for", neighbors))
    next  # Skip if no raters intersect
  }

  #Grids overlapping tile
  grids_over_tile<-subset(grid,TileID==tile)$grid_id
  
  grid_sub<-grid_dissolve[grid_dissolve$grid_id %in% grids_over_tile, ]
  
  cat("Transforming grid to match raster...\n")
  target<-crs(merged_raster, describe=T)$code
  grid_sub<-st_transform(grid_sub, as.numeric(target))
  grid_sub <- grid_sub[st_geometry_type(grid_sub) %in% c("POLYGON", "MULTIPOLYGON"), ]
  
  
  cat("Extracting raster to grid...\n")
  grid_sub$lai<-raster::extract(merged_raster, grid_sub, fun=mean, na.rm=TRUE)
  LAI_df <- rbind(LAI_df, as.data.frame(grid_sub))
}

LAI_df_out <- LAI_df %>%
  group_by(grid_id) %>%
  slice(1) %>%
  ungroup() 
LAI_df_out<-as.data.frame(LAI_df_out)
LAI_df_out<-LAI_df_out[,-c(2)]
head(LAI_df_out)
dim(LAI_df_out)
LAI_df_out$lai_val<-LAI_df_out$lai$NEON_D01_HARV_DP3_722000_4705000_LAI
LAI_df_out<-LAI_df_out[,-c(2)]
head(LAI_df_out)

write.csv(LAI_df_out,paste0("../ScalingAcrossResolution/LAIDatasets/",site,"_gridLAI.csv"))

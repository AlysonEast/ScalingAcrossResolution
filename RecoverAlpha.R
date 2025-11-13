setwd("/fs/ess/PUOM0017/ForestScaling/DeepForest")

install.packages("/users/PAS2136/alyeast/ScalingFromSky_0.0.0.9000.tar.gz", repos = NULL, type="source")

library(sf)
library(dplyr)
library(ggplot2) # Added for plotting
library(purrr)
library(stringr)
library(tibble)
library(VGAM)
library(data.table)
library(rstan)
library(posterior)
library(ScalingFromSky)

library(itcSegment)

product<-"NAIP"
site<-"HARV"

#### Make 1ha Processing Grid ####
AOP<-st_read(paste0("./Shapefiles/",product,"_AOP.shp"))
grid <- st_make_grid(polygons, cellsize = 100, square = TRUE) %>%
  st_sf(grid_id = 1:length(.), geometry = .)

#### Process shape files to have information for Size-Abundance Scaling
files<-list.files(paste0("./Outputs/",product,"/",site,"/"), pattern = ".*shp")
file<-files[1]
file

crowns<-st_read(paste0("./Outputs/",product,"/",site,"/",file))

# 2. Compute intersections
intersections <- st_intersection(
  crowns %>% select(crown_id, geometry),
  grid %>% select(grid_id, geometry)
)

# 3. Calculate overlap area
intersections <- intersections %>%
  mutate(overlap_area = as.numeric(st_area(.)))

# 4. For each crown, find the grid cell with the largest overlap
assignment <- intersections %>%
  group_by(crown_id) %>%
  slice_max(overlap_area, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  select(crown_id, grid_id)

# 5. Join grid ID back to crown polygons
crowns_assigned <- crowns %>%
  left_join(assignment, by = "crown_id")


chm<-raster("./LiDAR/NEON/HARV/DP3.30015.001/neon-aop-products/2022/FullSite/D01/2022_HARV_7/L3/DiscreteLidar/CanopyHeightModelGtif/NEON_D01_HARV_DP3_725000_4705000_CHM.tif")

#Take area, perimeter, and Heights 
crowns_assigned$Area <- st_area(crowns_assigned)
crowns_assigned$Perimeter <- polyPerimeter(crowns_assigned)
crowns_assigned$Max_Height<-extract(chm, crowns_assigned, fun='max', na.rm=TRUE)

crowns_assigned$Diameter<-0.5*(sqrt((df$Perimeter^2)-(8*df$Area)))


crowns_assigned$IDhect

# Load the sample data included with the package
data("harv_data_sample")

head(harv_data_sample)

df_tile <- harv_data_sample %>%
  filter(IDhectbest == 1, !is.na(dbh)) %>%
  select(dbh)

?get_potential_breakpoint_and_kde()
kde_output <- get_potential_breakpoint_and_kde(df_tile)
kde_output

cat("### Estimated Breakpoint\n")
cat(10^kde_output$potential_breakpoint, "cm")

trunc_output <- determine_truncation_and_filter(kde_output)

fit <- fit_alpha_model(
  bayesian_data = trunc_output$bayesian_data,
  breakpoint = trunc_output$final_breakpoint,
  LAI = 5.426,            # Example LAI value for the site
  prior_mean = 1.4,
  prior_sd = 0.3
)

# Create a data frame for plotting the fitted line
plot_data <- tibble(
  dbh = seq(10, 50, length.out = 100),
  fit_n_dbh = dpareto(dbh, shape = fit$posterior_summary$mean, scale = 10)
)

# Plot the distribution and the fitted model
ggplot(trunc_output$bayesian_data, aes(x = dbh)) +
  geom_line(data = plot_data, aes(x = dbh, y = fit_n_dbh), color = "red", size = 1) +
  # scale_x_continuous(trans = 'log10') +
  # scale_y_continuous(trans = 'log10') +
  labs(title = "Estimated Size-Abundance (Density) Distribution",
       x = "Diameter at Breast Height (cm)",
       y = "Tree Density") +
  theme_bw()

trees <- estimate_total_trees(alpha_model_output = fit)

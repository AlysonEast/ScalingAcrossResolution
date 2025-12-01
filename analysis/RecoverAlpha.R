source(file.path(Sys.getenv("LMOD_PKG"), "init/R"))
module("load", "proj/9.2.1")
module("load", "gdal/3.7.3")

dyn.load("/apps/spack/0.21/pitzer/linux-rhel9-skylake/proj/gcc/12.3.0/9.2.1-buhooyr/lib64/libproj.so")
dyn.load("/apps/spack/0.21/pitzer/linux-rhel9-skylake/gdal/gcc/12.3.0/3.7.3-wmnbnyd/lib64/libgdal.so")

setwd("/fs/ess/PUOM0017/ForestScaling/ScalingAcrossResolution")

#install.packages("/users/PAS2136/alyeast/ScalingFromSky_0.0.0.9000.tar.gz", repos = NULL, type="source")

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

setwd("/fs/ess/PUOM0017/ForestScaling/ScalingAcrossResolution")

#### Process shape files to have information for Size-Abundance Scaling
files<-list.files(paste0("./CrownDatasets/"), pattern = paste0(site,"_",product), full.names = TRUE)
#file<-files[1]
#file

# Load the sample data included with the package
#df<-read.csv(paste0("./CrownDatasets/",file), header = TRUE, sep = ",")
data_list <- lapply(files, read.csv) # or readxl::read_excel for Excel files
df <- do.call(rbind, data_list)
head(df)

table(df$image_path)

df<-subset(df, image_path == "NAIP_30cm_HARV_7_725000_4705000.tif" |
             image_path == "NAIP_30cm_HARV_7_724000_4706000.tif" |
             image_path == "NAIP_30cm_HARV_7_724000_4705000.tif"|
             image_path == "NAIP_30cm_HARV_7_725000_4706000.tif")

grid_list<-unique(df$grid_id)

lai_df<-read.csv(paste0("LAIDatasets/",site,"_gridLAI.csv"))
str(lai_df)

# Initialize empty lists to store results
alpha_results <- data.frame(matrix(ncol = 12, nrow = 0))  # will store posterior summaries for alpha (power-law exponent) for each plot
colnames(alpha_results)<-c("variable","mean","median","sd","mad","q5","q95","rhat","ess_bulk","ess_tail R2_kernel","grid")

tree_results <- data.frame(matrix(ncol = 12, nrow = 0))   # will store posterior summaries for total number of trees (N_tot) for each plot
colnames(alpha_results)<-c("variable","mean","median","sd","mad","q5","q95","rhat","ess_bulk","ess_tail R2_kernel","grid")

hist(table(df$grid_id))

for (i in 1:10) {#dim(table(df$grid_id))) {
  df_tile <- subset(df, grid_id == grid_list[i])
  if (dim(df_tile)[1] < 75) {
    print(paste("Not enough data to fit model", grid_list[i]))
    next  # Skip if no raters intersect
  }
  cat("Grid ID: ", grid_list[i], "number ", i, " of 10","\n")
  cat("Number of crowns: ", dim(df_tile)[1],"\n")
  cat("DBH min: ", min(df_tile$DBH))
  cat(", mean: ", mean(df_tile$DBH))
  cat(", max: ", max(df_tile$DBH),"\n")

  LAI<-subset(lai_df, grid_id==grid_list[i])
  if (length(LAI) == 0) {
    print(paste("No matching LAI values for tile", grid_list[i]))
    next  # Skip if no raters intersect
  }
  
  kde_output <- get_potential_breakpoint_and_kde(df_tile$DBH)
  
  cat("### Estimated Breakpoint\n")
  cat(10^kde_output$potential_breakpoint, "cm")

  trunc_output <- determine_truncation_and_filter(kde_output)
  
  LAI<-subset(lai_df, grid_id==grid_list[i])
  
  fit <- fit_alpha_model(
    bayesian_data = trunc_output$bayesian_data,
    breakpoint = trunc_output$final_breakpoint,
    LAI = LAI$lai_val,            # Example LAI value for the site
    prior_mean = 1.4,
    prior_sd = 0.3
  )
  
  # Create a data frame for plotting the fitted line
  plot_data <- tibble(
    dbh = seq(10, 50, length.out = 100),
    fit_n_dbh = dpareto(dbh, shape = fit$posterior_summary$mean, scale = 10)
  )

  # Plot the distribution and the fitted model
  # ggplot(trunc_output$bayesian_data, aes(x = dbh)) +
  #   geom_line(data = plot_data, aes(x = dbh, y = fit_n_dbh), color = "red", size = 1) +
  #   # scale_x_continuous(trans = 'log10') +
  #   # scale_y_continuous(trans = 'log10') +
  #   labs(title = "Estimated Size-Abundance (Density) Distribution",
  #        x = "Diameter at Breast Height (cm)",
  #        y = "Tree Density") +
  #   theme_bw()

  trees <- estimate_total_trees(alpha_model_output = fit)
  
  # Create a data frame for plotting the fitted line
  plot_data <- tibble(
    dbh = seq(10, 50, length.out = 100),
    fit_n_dbh = dpareto(dbh, shape = fit$posterior_summary$mean, scale = 10)* trees$posterior_summary$mean
  )
  
  # Plot the distribution and the fitted model
  # ggplot(trunc_output$bayesian_data, aes(x = dbh)) +
  #   geom_line(data = plot_data, aes(x = dbh, y = fit_n_dbh), color = "red", size = 1) +
  #   # scale_x_continuous(trans = 'log10') +
  #   # scale_y_continuous(trans = 'log10') +
  #   labs(title = "Estimated Size-Abundance Distribution",
  #        x = "Diameter at Breast Height (cm)",
  #        y = "Number of Trees") +
  #   theme_bw()
  
  # Store the results in the lists, using a unique plot identifier
  fit$posterior_summary$grid<-grid_list[i]
  trees$posterior_summary$grid<-grid_list[i]
    
  alpha_results<-rbind(alpha_results, fit$posterior_summary)  # posterior summary for alpha
  tree_results<-rbind(tree_results, trees$posterior_summary) # posterior summary for N_tot
}
alpha_results$site<-site
print("posterior summary for alpha:")
print(alpha_results)

tree_results$site<-site
print("posterior summary for N_tot:")
print(tree_results)

write.csv(alpha_results, paste0("./Results/",site,"_",product,"_alpha.csv"))
write.csv(alpha_results, paste0("./Results/",site,"_",product,"_trees.csv"))

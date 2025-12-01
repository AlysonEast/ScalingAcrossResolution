source(file.path(Sys.getenv("LMOD_PKG"), "init/R"))
module("load", "proj/9.2.1")
module("load", "gdal/3.7.3")

dyn.load("/apps/spack/0.21/pitzer/linux-rhel9-skylake/proj/gcc/12.3.0/9.2.1-buhooyr/lib64/libproj.so")
dyn.load("/apps/spack/0.21/pitzer/linux-rhel9-skylake/gdal/gcc/12.3.0/3.7.3-wmnbnyd/lib64/libgdal.so")

setwd("/fs/ess/PUOM0017/ForestScaling/ScalingAcrossResolution")

args <- commandArgs(trailingOnly = TRUE)
task_id <- as.numeric(args[1])
chunk_size <- as.numeric(args[1])
ncores <- as.numeric(args[3])

#cat("SLURM task:", task_id, "\n")
cat("Chunk size:", chunk_size, "\n")
#cat("Using", ncores, "cores inside job\n")

# -------------------------
# Parallel setup
# -------------------------
library(future)
library(future.apply)
plan(multicore, workers = ncores)

options(mc.cores = ncores)                     # Stan parallel chains
Sys.setenv(R_STAN_NUM_THREADS = ncores)        # Stan within-chain threads

# -------------------------
# Load libraries and data
# -------------------------

library(sf)
library(dplyr)
library(data.table)
library(rstan)
library(ScalingFromSky)
library(tibble)
library(VGAM)

setwd("/fs/ess/PUOM0017/ForestScaling/ScalingAcrossResolution")

product <- "NAIP"
site <- "HARV"

files <- list.files("./data/CrownDatasets/", 
                    pattern = paste0(site,"_",product), 
                    full.names = TRUE)

df <- do.call(rbind, lapply(files, read.csv))


df<-subset(df, image_path == "NAIP_30cm_HARV_7_725000_4705000.tif" |
             image_path == "NAIP_30cm_HARV_7_724000_4706000.tif" |
             image_path == "NAIP_30cm_HARV_7_724000_4705000.tif"|
             image_path == "NAIP_30cm_HARV_7_725000_4706000.tif")

lai_df <- read.csv(paste0("./data/LAI/", site, "_gridLAI.csv"))

grid_list <- unique(df$grid_id)
num_grids <- length(grid_list)
cat("Total grids:", num_grids, "\n")

# ------------------------------------------------------------
# Assign grids to this SLURM job
# ------------------------------------------------------------

start_index <- (task_id - 1) * chunk_size + 1
end_index   <- min(task_id * chunk_size, num_grids)

my_grids <- grid_list[start_index:end_index]

cat("Processing grids:", paste(my_grids, collapse = ", "), "\n")

# # Initialize storage
# alpha_results <- list()
# tree_results <- list()

# -------------------------
# FUNCTION to process one grid
# -------------------------
# process_grid <- function(grid) {
#   
#   df_tile <- subset(df, grid_id == grid)
#   if (nrow(df_tile) < 100) return(NULL)
#   
#   LAI_row <- subset(lai_df, grid_id == grid)
#   if (nrow(LAI_row) == 0) return(NULL)
#   
#   kde_output  <- get_potential_breakpoint_and_kde(df_tile$DBH)
#   trunc_output <- determine_truncation_and_filter(kde_output)
#   
#   fit <- fit_alpha_model(
#     bayesian_data = trunc_output$bayesian_data,
#     breakpoint = trunc_output$final_breakpoint,
#     LAI = LAI_row$lai_val,
#     prior_mean = 1.4,
#     prior_sd = 0.3
#   )
#   
#   trees <- estimate_total_trees(fit)
#   
#   fit$posterior_summary$grid <- grid
#   trees$posterior_summary$grid <- grid
#   
#   list(alpha = fit$posterior_summary,
#        trees = trees$posterior_summary)
# }
# 
# # -------------------------
# # PARALLEL EXECUTION
# # -------------------------
# results <- future_lapply(my_grids, process_grid)
# 
# alpha_all <- do.call(rbind, lapply(results, `[[`, "alpha"))
# trees_all <- do.call(rbind, lapply(results, `[[`, "trees"))
# 
# # -------------------------
# # SAVE OUTPUT
# # -------------------------
# alpha_file <- sprintf("./Results/%s_%s_alpha_chunk_%03d.csv", site, product, task_id)
# tree_file  <- sprintf("./Results/%s_%s_tree_chunk_%03d.csv", site, product, task_id)
# 
# write.csv(alpha_all, alpha_file, row.names = FALSE)
# write.csv(trees_all, tree_file, row.names = FALSE)
# 
# cat("Saved:", alpha_file, "\n")
# cat("Saved:", tree_file,  "\n")

# Initialize empty lists to store results
alpha_results <- data.frame(matrix(ncol = 12, nrow = 0))  # will store posterior summaries for alpha (power-law exponent) for each plot
colnames(alpha_results)<-c("variable","mean","median","sd","mad","q5","q95","rhat","ess_bulk","ess_tail R2_kernel","grid")

tree_results <- data.frame(matrix(ncol = 12, nrow = 0))   # will store posterior summaries for total number of trees (N_tot) for each plot
colnames(alpha_results)<-c("variable","mean","median","sd","mad","q5","q95","rhat","ess_bulk","ess_tail R2_kernel","grid")

hist(table(df$grid_id))

for (i in start_index:end_index) {#dim(table(df$grid_id))) {
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
  
  fit <- tryCatch(
    {
      fit_alpha_model(
        bayesian_data = trunc_output$bayesian_data,
        breakpoint = trunc_output$final_breakpoint,
        LAI = LAI$lai_val,
        prior_mean = 1.4,
        prior_sd = 0.3
      )
    },
    error = function(e) {
      cat("Error fitting alpha model for grid", grid_list[i], ":", e$message, "\nSkipping.\n")
      return(NULL)
    }
  )
  
  if (is.null(fit)) next
  
  trees <- estimate_total_trees(alpha_model_output = fit)
  
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

write.csv(alpha_results, paste0("./Results/Parameters/",site,"/",product,"/Chunks/",site,"_",product,"_chunk",task_id,"_alpha.csv"))
write.csv(alpha_results, paste0("./Results/Parameters/",site,"/",product,"/Chunks/",site,"_",product,"_chunk",task_id,"_trees.csv"))

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

product <-"Weinstein" #"NAIP", "Weinstein", or "MAXAR"
site <- "HARV"

files <- list.files("./data/CrownDatasets/", 
                    pattern = paste0(site,"_",product), 
                    full.names = TRUE)

header<-read.csv(files[1], nrows = 1, header = FALSE)
as.list(header[1,])
colnames(header)<-as.list(header[1,])
colnames(header)

files<-c("./data/CrownDatasets//HARV_Weinstein_trees_725000_4705000.csv",
         "./data/CrownDatasets//HARV_Weinstein_trees_724000_4706000.csv",
         "./data/CrownDatasets//HARV_Weinstein_trees_724000_4705000.csv",
         "./data/CrownDatasets//HARV_Weinstein_trees_725000_4706000.csv")


df <- do.call(rbind, lapply(files, function(f) {
  x <- read.csv(f, skip = 1, header = FALSE)
  x$image_path <- basename(f)   # add filename (or use f for full path)
  x
}))

df2<-df[,c(1:9,19:ncol(df))]
head(df2)
colnames(df2)<-c(colnames(header),"image_path")
head(df2)

df<-subset(df2, image_path == "HARV_Weinstein_trees_725000_4705000.csv" |
             image_path == "HARV_Weinstein_trees_724000_4706000.csv" |
             image_path == "HARV_Weinstein_trees_724000_4705000.csv"|
             image_path == "HARV_Weinstein_trees_725000_4706000.csv")


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

# Initialize empty lists to store results
alpha_results <- data.frame(matrix(ncol = 12, nrow = 0))  # will store posterior summaries for alpha (power-law exponent) for each plot
colnames(alpha_results)<-c("variable","mean","median","sd","mad","q5","q95","rhat","ess_bulk","ess_tail R2_kernel","grid")

tree_results <- data.frame(matrix(ncol = 12, nrow = 0))   # will store posterior summaries for total number of trees (N_tot) for each plot
colnames(alpha_results)<-c("variable","mean","median","sd","mad","q5","q95","rhat","ess_bulk","ess_tail R2_kernel","grid")

hist(table(df$grid_id))

for (i in start_index:end_index) {#dim(table(df$grid_id))) {
  df_tile <- subset(df, grid_id == grid_list[i])
  # if (dim(df_tile)[1] < 75) {
  #   print(paste("Not enough data to fit model", grid_list[i]))
  #   next  # Skip if no raters intersect
  # }
  cat("Grid ID: ", grid_list[i], "number ", i, " of ", end_index,"\n")
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

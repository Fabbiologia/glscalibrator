## ----setup, include = FALSE---------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  eval = FALSE
)

## ----install------------------------------------------------------------------
# # Install from GitHub
# # install.packages("devtools")
# devtools::install_github("fabbiologia/glscalibrator")
# 
# # Load the package
# library(glscalibrator)

## ----batch--------------------------------------------------------------------
# results <- calibrate_gls_batch(
#   data_dir = system.file("extdata", package = "glscalibrator"),
#   output_dir = "data/processed/calibration",
#   colony_lat = 27.85178,    # Your colony latitude
#   colony_lon = -115.17390,  # Your colony longitude
#   light_threshold = 2,      # Light threshold in lux
#   verbose = TRUE
# )

## ----results------------------------------------------------------------------
# # Summary statistics for all birds
# print(results$summary)
# 
# # Processing log (successes and failures)
# print(results$processing_log)
# 
# # Access individual bird positions
# bird_data <- results$results$BW154_05Jul24_225805
# head(bird_data)

## ----equinox------------------------------------------------------------------
# # Define equinox exclusion windows
# equinoxes <- list(
#   c("2024-08-24", "2024-10-23"),  # Autumn
#   c("2024-02-19", "2024-04-19"),  # Spring
#   c("2023-08-24", "2023-10-23")   # Previous year
# )
# 
# results <- calibrate_gls_batch(
#   data_dir = "data/raw/birds",
#   output_dir = "data/processed/calibration",
#   colony_lat = 27.85,
#   colony_lon = -115.17,
#   exclude_equinoxes = equinoxes
# )

## ----custom-------------------------------------------------------------------
# results <- calibrate_gls_batch(
#   data_dir = "data/raw/birds",
#   output_dir = "data/processed/calibration",
#   colony_lat = 27.85,
#   colony_lon = -115.17,
#   light_threshold = 3,      # Higher threshold
#   min_positions = 20,       # Require more positions
#   create_plots = FALSE      # Skip plot generation
# )
# 
# # metadata table is also exported for programmatic access
# glscalibrator_example_metadata

## ----read---------------------------------------------------------------------
# light_data <- read_lux_file(gls_example("W086"))
# head(light_data)

## ----calib--------------------------------------------------------------------
# calib_period <- auto_detect_calibration(
#   light_data,
#   colony_lat = 27.85178,
#   colony_lon = -115.17390,
#   threshold = 2
# )
# 
# print(calib_period)
# # $start
# # [1] "2024-07-05 22:58:05 UTC"
# # $end
# # [1] "2024-07-07 22:58:05 UTC"
# # $twilights
# # [1] 5

## ----twilights----------------------------------------------------------------
# twilights <- detect_twilights(light_data, threshold = 2)
# head(twilights)

## ----filter-------------------------------------------------------------------
# twilights_clean <- filter_twilights(
#   twilights,
#   light_data = light_data,
#   threshold = 2,
#   strict = TRUE
# )

## ----sgat---------------------------------------------------------------------
# library(SGAT)
# 
# calib_result <- thresholdCalibration(
#   twilights_clean$Twilight,
#   twilights_clean$Rise,
#   lon = -115.17390,
#   lat = 27.85178,
#   method = 'gamma'
# )
# 
# zenith <- calib_result[1]
# print(paste("Zenith angle:", round(zenith, 2), "degrees"))

## ----summary------------------------------------------------------------------
# # Example calibration_summary.csv structure:
# # bird_id              zenith  sun_elevation  n_twilights_calib  n_positions  hemisphere_check
# # BW154_05Jul24_225805  98.74       -8.74              5              143     CORRECT (Western)
# # BW157_05Jul24_231215  98.39       -8.39              5              274     CORRECT (Western)

## ----positions----------------------------------------------------------------
# # Example [bird_id]_calibrated.csv structure:
# # bird_id    datetime            date        Longitude  Latitude  zenith  method
# # BW154      2024-07-08 05:30:00 2024-07-08  -115.2     27.9      98.74   threshold_crossing_SGAT_gamma

## ----quality------------------------------------------------------------------
# # Check calibration diagnostics
# # Look at [bird_id]_calibration.png files
# 
# # Check hemisphere in summary
# summary <- read.csv("data/processed/calibration/data/calibration_summary.csv")
# table(summary$hemisphere_check)
# 
# # Review failed birds
# failed <- results$processing_log[
#   sapply(results$processing_log, function(x) x$status == "FAILED")
# ]
# print(failed)


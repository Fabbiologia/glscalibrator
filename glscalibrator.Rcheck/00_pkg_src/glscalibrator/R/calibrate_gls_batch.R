#' Batch Calibration of Multiple GLS Devices
#'
#' Main function for automated batch processing of GLS data. Auto-discovers
#' all birds in a directory, detects calibration periods, performs TwGeos
#' gamma calibration, and generates standardized outputs.
#'
#' @param data_dir Character path to directory containing .lux files
#' @param output_dir Character path for output files
#' @param colony_lat Numeric latitude of colony/capture location
#' @param colony_lon Numeric longitude of colony/capture location
#' @param light_threshold Numeric light threshold in lux (default: 2)
#' @param exclude_equinoxes List of date ranges to exclude (optional)
#' @param min_positions Minimum number of valid positions required (default: 10)
#' @param create_plots Logical, whether to create diagnostic plots (default: TRUE)
#' @param verbose Logical, print progress messages (default: TRUE)
#'
#' @return A list containing:
#'   \item{summary}{data.frame with calibration summary for all birds}
#'   \item{results}{List of position estimates for each bird}
#'   \item{processing_log}{Detailed processing log}
#'
#' @details
#' This function implements a complete automated workflow:
#' \enumerate{
#'   \item Auto-discovers .lux files in the data directory
#'   \item For each bird:
#'     \itemize{
#'       \item Reads light data
#'       \item Auto-detects calibration period
#'       \item Detects and filters twilights
#'       \item Performs TwGeos gamma calibration
#'       \item Calculates positions using threshold method
#'       \item Generates diagnostic plots
#'     }
#'   \item Combines results into standardized formats
#'   \item Creates summary statistics and quality control metrics
#' }
#'
#' @examples
#' \dontrun{
#' # Basic usage
#' results <- calibrate_gls_batch(
#'   data_dir = "data/raw/birds",
#'   output_dir = "data/processed/calibration",
#'   colony_lat = 27.85178,
#'   colony_lon = -115.17390
#' )
#'
#' # With equinox exclusions
#' equinoxes <- list(
#'   c("2024-08-24", "2024-10-23"),
#'   c("2024-02-19", "2024-04-19")
#' )
#' results <- calibrate_gls_batch(
#'   data_dir = "data/raw/birds",
#'   output_dir = "data/processed/calibration",
#'   colony_lat = 27.85,
#'   colony_lon = -115.17,
#'   exclude_equinoxes = equinoxes
#' )
#' }
#'
#' @export
#' @importFrom dplyr bind_rows filter mutate lead
#' @importFrom GeoLight coord
#' @importFrom stringr str_replace
#' @importFrom magrittr %>%
#' @importFrom utils write.csv
#' @importFrom stats median
#' @importFrom TwGeos thresholdCalibration
calibrate_gls_batch <- function(data_dir,
                                 output_dir,
                                 colony_lat,
                                 colony_lon,
                                 light_threshold = 2,
                                 exclude_equinoxes = NULL,
                                 min_positions = 10,
                                 create_plots = TRUE,
                                 verbose = TRUE) {

  # Set timezone
  Sys.setenv(TZ = 'UTC')

  # Create output directories
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  data_output_dir <- file.path(output_dir, "data")
  fig_dir <- file.path(output_dir, "figures")
  dir.create(data_output_dir, recursive = TRUE, showWarnings = FALSE)
  if (create_plots) {
    dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
  }

  if (verbose) {
    cat("\n================================================================================\n")
    cat("   GLS CALIBRATION - BATCH PROCESSING\n")
    cat("================================================================================\n\n")
    cat(sprintf("Colony: %.5f\u00b0N, %.5f\u00b0W\n", colony_lat, abs(colony_lon)))
    cat(sprintf("Light threshold: %d lux\n", light_threshold))
    cat(sprintf("Output: %s\n\n", output_dir))
  }

  # Discover birds
  lux_files <- list.files(
    data_dir,
    pattern = "\\.lux$",
    recursive = TRUE,
    full.names = TRUE
  ) %>%
    .[!grepl("driftadj", .)]

  if (length(lux_files) == 0) {
    stop("No .lux files found in ", data_dir)
  }

  bird_info <- data.frame(
    file_path = lux_files,
    bird_id = basename(lux_files) %>% stringr::str_replace("\\.lux$", "")
  )

  if (verbose) {
    cat(sprintf("Found %d birds to process\n\n", nrow(bird_info)))
  }

  # Initialize storage
  all_results <- list()
  all_calibrations <- data.frame()
  all_gls_merge <- list()
  processing_log <- list()

  # Process each bird
  for (i in 1:nrow(bird_info)) {
    bird_id <- bird_info$bird_id[i]
    lux_file <- bird_info$file_path[i]

    if (verbose) {
      cat(sprintf("\n[%d/%d] Processing: %s\n", i, nrow(bird_info), bird_id))
      cat("--------------------------------------------\n")
    }

    log_entry <- list(
      bird_id = bird_id,
      file_path = lux_file,
      status = "started",
      error = NA,
      n_calibration_twilights = 0,
      n_deployment_twilights = 0,
      n_positions = 0,
      zenith = NA,
      hemisphere = NA
    )

    tryCatch({
      # Process bird
      bird_result <- process_single_bird(
        lux_file = lux_file,
        bird_id = bird_id,
        colony_lat = colony_lat,
        colony_lon = colony_lon,
        light_threshold = light_threshold,
        exclude_equinoxes = exclude_equinoxes,
        output_dir = data_output_dir,
        fig_dir = if (create_plots) fig_dir else NULL,
        verbose = verbose
      )

      # Store results
      all_results[[bird_id]] <- bird_result$positions
      all_calibrations <- bind_rows(all_calibrations, bird_result$summary)
      all_gls_merge[[bird_id]] <- bird_result$gls_merge

      log_entry$status <- "SUCCESS"
      log_entry$n_calibration_twilights <- bird_result$summary$n_twilights_calib
      log_entry$n_deployment_twilights <- bird_result$summary$n_twilights_full
      log_entry$n_positions <- nrow(bird_result$positions)
      log_entry$zenith <- bird_result$summary$zenith
      log_entry$hemisphere <- bird_result$summary$hemisphere_check

      if (verbose) cat("[OK] SUCCESS\n")

    }, error = function(e) {
      log_entry$status <<- "FAILED"
      log_entry$error <<- e$message
      if (verbose) cat(sprintf("[X] FAILED: %s\n", e$message))
    })

    processing_log[[bird_id]] <- log_entry
  }

  # Save combined outputs
  if (length(all_results) > 0) {
    write.csv(all_calibrations,
              file.path(data_output_dir, "calibration_summary.csv"),
              row.names = FALSE)

    combined_gls <- bind_rows(all_gls_merge)
    write.csv(combined_gls,
              file.path(data_output_dir, "GLSmergedata.csv"),
              row.names = FALSE)

    combined <- bind_rows(all_results)
    write.csv(combined,
              file.path(data_output_dir, "all_birds_calibrated.csv"),
              row.names = FALSE)
  }

  # Print summary
  if (verbose) {
    n_success <- sum(sapply(processing_log, function(x) x$status == "SUCCESS"))
    n_failed <- sum(sapply(processing_log, function(x) x$status == "FAILED"))

    cat("\n\n================================================================================\n")
    cat("SUMMARY\n")
    cat("================================================================================\n\n")
    cat(sprintf("Total birds: %d\n", length(processing_log)))
    cat(sprintf("Successfully processed: %d\n", n_success))
    cat(sprintf("Failed: %d\n\n", n_failed))
  }

  return(list(
    summary = all_calibrations,
    results = all_results,
    processing_log = processing_log
  ))
}


#' Process a Single Bird
#'
#' Internal function to process a single GLS device
#'
#' @keywords internal
process_single_bird <- function(lux_file, bird_id, colony_lat, colony_lon,
                                 light_threshold, exclude_equinoxes,
                                 output_dir, fig_dir, verbose) {

  # Read data
  if (verbose) cat("  Reading light data...\n")
  d.lux <- read_lux_file(lux_file)

  # Auto-detect calibration
  if (verbose) cat("  Auto-detecting calibration period...\n")
  calib_period <- auto_detect_calibration(d.lux, colony_lat, colony_lon,
                                           light_threshold)

  # Extract calibration data
  PD_colony <- d.lux %>%
    filter(Date >= calib_period$start & Date <= calib_period$end)

  # Detect twilights
  twl_colony_raw <- detect_twilights(PD_colony, light_threshold)
  twl_colony <- filter_twilights(twl_colony_raw, PD_colony, light_threshold, strict = TRUE)

  # Threshold calibration using gamma method
  if (verbose) cat("  Performing gamma calibration...\n")
  calib_colony <- TwGeos::thresholdCalibration(
    twl_colony$Twilight,
    twl_colony$Rise,
    colony_lon,
    colony_lat,
    method = 'gamma'
  )

  zenith_colony <- calib_colony[1]

  # Process deployment
  if (verbose) cat("  Processing deployment data...\n")
  deploy_start <- calib_period$end
  d_deploy <- d.lux %>% filter(Date >= deploy_start)

  twl_deploy_raw <- detect_twilights(d_deploy, light_threshold)
  twl_deploy <- filter_twilights(twl_deploy_raw, d_deploy, light_threshold, strict = FALSE)

  # Calculate positions
  if (verbose) cat("  Calculating positions...\n")
  twl_geolight <- twl_deploy %>%
    mutate(
      tFirst = Twilight,
      tSecond = lead(Twilight),
      type = ifelse(Rise, 1, 2)
    ) %>%
    filter(!is.na(tSecond))

  coords <- GeoLight::coord(
    tFirst = twl_geolight$tFirst,
    tSecond = twl_geolight$tSecond,
    type = twl_geolight$type,
    degElevation = 90 - zenith_colony
  )

  results <- data.frame(
    bird_id = bird_id,
    datetime = twl_geolight$tFirst,
    date = as.Date(twl_geolight$tFirst),
    Longitude = coords[, 1],
    Latitude = coords[, 2],
    zenith = zenith_colony,
    sun_elevation = 90 - zenith_colony,
    method = "threshold_crossing_TwGeos_gamma"
  )

  # Exclude equinoxes
  if (!is.null(exclude_equinoxes)) {
    for (equinox_period in exclude_equinoxes) {
      results <- results %>%
        filter(!(date >= as.Date(equinox_period[1]) &
                   date <= as.Date(equinox_period[2])))
    }
  }

  # Filter coordinates
  results <- results %>%
    filter(Latitude >= -60 & Latitude <= 60,
           Longitude >= -180 & Longitude <= 180)

  # Hemisphere check
  hemisphere <- ifelse(median(results$Longitude) < 0,
                       "CORRECT (Western)", "WRONG (Eastern)")

  # Save outputs
  write.csv(results, file.path(output_dir, paste0(bird_id, "_calibrated.csv")),
            row.names = FALSE)

  gls_merge <- convert_to_glsmerge(results, bird_id, zenith_colony)
  write.csv(gls_merge, file.path(output_dir, paste0(bird_id, "_GLSmergedata.csv")),
            row.names = FALSE)

  # Create plots if requested
  if (!is.null(fig_dir)) {
    plot_calibration(PD_colony, twl_colony, light_threshold, bird_id, fig_dir)
    plot_track(results, colony_lat, colony_lon, bird_id, fig_dir, hemisphere)
  }

  # Summary
  summary_df <- data.frame(
    bird_id = bird_id,
    zenith = zenith_colony,
    sun_elevation = 90 - zenith_colony,
    n_twilights_calib = nrow(twl_colony),
    n_twilights_full = nrow(twl_deploy),
    n_positions = nrow(results),
    lat_median = round(median(results$Latitude), 2),
    lon_median = round(median(results$Longitude), 2),
    hemisphere_check = hemisphere
  )

  return(list(
    positions = results,
    summary = summary_df,
    gls_merge = gls_merge
  ))
}

#' Automatically Detect Calibration Period
#'
#' Automatically detects a suitable calibration period from the beginning of
#' the light data. This assumes the bird was at a known location (typically
#' the colony) at the start of deployment.
#'
#' @param light_data A data.frame with columns \code{Date} and \code{Light}
#' @param colony_lat Numeric latitude of known calibration location
#' @param colony_lon Numeric longitude of known calibration location
#' @param threshold Light threshold for twilight detection (default: 2)
#' @param min_twilights Minimum number of twilights required (default: 2)
#'
#' @return A list with:
#'   \item{start}{POSIXct start of calibration period}
#'   \item{end}{POSIXct end of calibration period}
#'   \item{twilights}{Number of twilights detected}
#'   \item{duration_days}{Duration in days}
#'
#' @details
#' The function tries calibration periods of different lengths (2, 3, 1, 4, 5
#' days) and returns the first period that yields sufficient twilights with
#' both sunrise and sunset events.
#'
#' @examples
#' \donttest{
#' # Auto-detect calibration from example data (requires SGAT)
#' example_file <- gls_example("W086")
#' light_data <- read_lux_file(example_file)
#' calib <- auto_detect_calibration(light_data,
#'                                   colony_lat = 27.85,
#'                                   colony_lon = -115.17)
#' print(calib)
#' }
#'
#' @export
#' @importFrom dplyr filter
#' @importFrom lubridate days
#' @importFrom magrittr %>%
auto_detect_calibration <- function(light_data, colony_lat, colony_lon,
                                     threshold = 2, min_twilights = 2) {

  # Get first 10 days of data
  start_date <- min(light_data$Date)
  first_10_days <- light_data %>%
    filter(Date <= start_date + days(10))

  if (nrow(first_10_days) < 100) {
    stop("Insufficient data in first 10 days")
  }

  # Try different calibration durations
  for (duration in c(2, 3, 1, 4, 5)) {
    period_data <- light_data %>%
      filter(Date >= start_date & Date <= start_date + days(duration))

    twl_test <- detect_twilights(period_data, threshold)

    if (!is.null(twl_test) && nrow(twl_test) >= min_twilights) {
      # Check we have both sunrise and sunset
      if (length(unique(twl_test$Rise)) >= 2) {
        calib_start <- start_date
        calib_end <- start_date + days(duration)

        return(list(
          start = calib_start,
          end = calib_end,
          twilights = nrow(twl_test),
          duration_days = duration
        ))
      }
    }
  }

  stop("Could not detect valid calibration period")
}

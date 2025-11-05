#' Detect Twilight Times from Light Data
#'
#' Detects sunrise and sunset times from light intensity data using a
#' threshold-crossing method. This is a proven, simple approach that
#' identifies transitions between day and night.
#'
#' @param light_data A data.frame with columns \code{Date} (POSIXct) and
#'   \code{Light} (numeric)
#' @param threshold Numeric light threshold in lux for day/night distinction
#'   (default: 2)
#'
#' @return A data.frame with columns:
#'   \item{Twilight}{POSIXct datetime of twilight event}
#'   \item{Rise}{Logical, TRUE for sunrise, FALSE for sunset}
#'
#' @examples
#' # Detect twilights from example data
#' example_file <- gls_example("W086")
#' light_data <- read_lux_file(example_file)
#' twilights <- detect_twilights(light_data, threshold = 2)
#' head(twilights)
#'
#' @export
#' @importFrom dplyr filter arrange mutate
#' @importFrom magrittr %>%
detect_twilights <- function(light_data, threshold = 2) {

  # Check required columns
  if (!all(c("Date", "Light") %in% colnames(light_data))) {
    stop("light_data must have 'Date' and 'Light' columns")
  }

  # Clean and sort data
  light_data <- light_data %>%
    filter(!is.na(Date), !is.na(Light)) %>%
    arrange(Date)

  if (nrow(light_data) < 2) {
    warning("Insufficient data points")
    return(NULL)
  }

  # Classify day/night
  light_data <- light_data %>%
    mutate(is_day = Light > threshold)

  # Find transitions (day->night or night->day)
  transitions <- which(diff(as.numeric(light_data$is_day)) != 0)

  if (length(transitions) == 0) {
    warning("No twilight transitions detected")
    return(NULL)
  }

  # Create twilight data.frame
  twilights <- data.frame(
    Twilight = light_data$Date[transitions + 1],
    Rise = light_data$is_day[transitions + 1]
  )

  return(twilights)
}

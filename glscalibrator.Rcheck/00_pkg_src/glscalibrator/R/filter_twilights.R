#' Filter and Clean Twilight Data
#'
#' Applies quality filters to twilight data to remove spurious detections
#' caused by shading, logger malfunction, or other artifacts.
#'
#' @param twilights A data.frame with columns \code{Twilight} and \code{Rise}
#' @param light_data The original light data (optional, for quality checks)
#' @param threshold Light threshold used for twilight detection
#' @param strict Logical, if TRUE applies stricter filtering (default: TRUE)
#'
#' @return A filtered data.frame of twilights
#'
#' @details
#' Filters applied:
#' \itemize{
#'   \item Remove twilights too close together (< 1-2 hours)
#'   \item Remove twilights with unusual intervals (far from 12 or 24 hours)
#'   \item Optionally check light quality around twilight (if light_data provided)
#' }
#'
#' @examples
#' # Filter twilights from example data
#' example_file <- gls_example("W086")
#' light_data <- read_lux_file(example_file)
#' twilights <- detect_twilights(light_data, threshold = 2)
#' twilights_clean <- filter_twilights(twilights, light_data, threshold = 2)
#' nrow(twilights_clean)
#'
#' @export
#' @importFrom dplyr filter arrange mutate lag
filter_twilights <- function(twilights, light_data = NULL, threshold = 2, strict = TRUE) {

  # Sort by time
  twilights <- twilights %>%
    arrange(Twilight) %>%
    mutate(
      time_since_last = as.numeric(difftime(Twilight, lag(Twilight), units = "hours")),
      expected_interval = ifelse(Rise == lag(Rise), 24, 12)
    )

  n_original <- nrow(twilights)

  # Filter 1: Remove very close twilights
  min_gap <- if (strict) 1 else 2
  twilights <- twilights %>%
    filter(is.na(time_since_last) | time_since_last > min_gap)

  n_after_close <- nrow(twilights)

  # Filter 2: Remove twilights with unusual intervals
  if (nrow(twilights) > 4) {
    twilights <- twilights %>%
      filter(is.na(expected_interval) |
               abs(time_since_last - expected_interval) < 8)
  }

  n_after_interval <- nrow(twilights)

  # Filter 3: Check light quality (only if not strict and we have light data)
  if (!strict && !is.null(light_data) && nrow(twilights) > 20) {
    twilights$light_quality <- sapply(1:nrow(twilights), function(i) {
      t <- twilights$Twilight[i]
      window <- light_data %>%
        filter(Date >= (t - 30*60) & Date <= (t + 30*60))

      if (nrow(window) < 5) return(TRUE)

      diffs <- diff(window$Light)
      max_jump <- max(abs(diffs), na.rm = TRUE)

      return(max_jump < 300)
    })

    twilights <- twilights %>% filter(light_quality == TRUE)
  }

  n_final <- nrow(twilights)

  message(sprintf("Twilight filtering: %d -> %d (removed %d)",
                  n_original, n_final, n_original - n_final))

  return(twilights)
}

#' Convert to GLSmerge Format
#'
#' Converts calibrated position data to the standard GLSmerge format used
#' by many researchers and analysis tools.
#'
#' @param results data.frame of position estimates
#' @param bird_id Character ID of the bird
#' @param zenith Numeric zenith angle used for calibration
#'
#' @return data.frame in GLSmerge format
#'
#' @export
#' @importFrom dplyr mutate select row_number
#' @importFrom lubridate hour
#' @importFrom magrittr %>%
convert_to_glsmerge <- function(results, bird_id, zenith) {

  gls_id <- sub("_.*", "", bird_id)

  gls_data <- results %>%
    mutate(
      Index = row_number(),
      ID = NA,
      sex = NA,
      sexn = NA,
      GLS = gls_id,
      First = format(date, "%m/%d/%Y"),
      mese = as.integer(format(date, "%m")),
      Quality_1 = 9,
      Second = format(datetime, "%d/%m/%Y %H:%M"),
      Quality_2 = 9,
      Type = ifelse(hour(datetime) < 12, "Midnight", "Midday"),
      ElevAngle = round(sun_elevation, 1)
    ) %>%
    select(Index, ID, sex, sexn, GLS, First, mese, Quality_1,
           Second, Quality_2, Type, Longitude, Latitude, ElevAngle)

  return(gls_data)
}

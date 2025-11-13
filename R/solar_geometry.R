#' Solar geometry helpers used internally by glscalibrator
#'
#' These functions implement the NOAA solar algorithms to replace the
#' archived GeoLight/TwGeos functionality with native code that keeps the
#' package on CRAN-friendly dependencies.
#'
#' @name solar_geometry_helpers
#' @keywords internal
NULL

solar_parameters <- function(datetime) {
  if (!inherits(datetime, "POSIXct")) {
    stop("datetime must be POSIXct")
  }

  rad <- pi / 180
  jd <- as.numeric(datetime) / 86400 + 2440587.5
  jc <- (jd - 2451545) / 36525

  geom_mean_long <- (280.46646 + jc * (36000.76983 + 0.0003032 * jc)) %% 360
  geom_mean_anom <- 357.52911 + jc * (35999.05029 - 0.0001537 * jc)
  ecc <- 0.016708634 - jc * (0.000042037 + 0.0000001267 * jc)

  eq_center <- sin(rad * geom_mean_anom) * (1.914602 - jc * (0.004817 + 0.000014 * jc)) +
    sin(rad * 2 * geom_mean_anom) * (0.019993 - 0.000101 * jc) +
    sin(rad * 3 * geom_mean_anom) * 0.000289

  true_long <- geom_mean_long + eq_center
  omega <- 125.04 - 1934.136 * jc
  apparent_long <- true_long - 0.00569 - 0.00478 * sin(rad * omega)

  seconds <- 21.448 - jc * (46.815 + jc * (0.00059 - jc * 0.001813))
  mean_obliq <- 23 + (26 + seconds / 60) / 60
  obliq_corr <- mean_obliq + 0.00256 * cos(rad * omega)

  y <- tan(rad * obliq_corr / 2)^2
  eq_time <- 4 / rad * (
    y * sin(rad * 2 * geom_mean_long) -
      2 * ecc * sin(rad * geom_mean_anom) +
      4 * ecc * y * sin(rad * geom_mean_anom) * cos(rad * 2 * geom_mean_long) -
      0.5 * y^2 * sin(rad * 4 * geom_mean_long) -
      1.25 * ecc^2 * sin(rad * 2 * geom_mean_anom)
  )

  solar_dec <- asin(sin(rad * obliq_corr) * sin(rad * apparent_long))
  sin_dec <- sin(solar_dec)
  cos_dec <- cos(solar_dec)

  solar_time <- ((jd - 0.5) %% 1 * 1440 + eq_time) / 4

  list(
    solar_time = solar_time,
    eqtime = eq_time,
    sin_dec = sin_dec,
    cos_dec = cos_dec
  )
}

predict_twilight_time <- function(twilight, lon, lat, rise, deg_elevation, iterations = 4) {
  if (!length(twilight)) {
    return(twilight)
  }
  lat_rad <- lat * pi / 180
  cos_z <- cos((90 - deg_elevation) * pi / 180)
  guess <- twilight

  for (iter in seq_len(iterations)) {
    sun <- solar_parameters(guess)
    cos_hour <- (cos_z - sin(lat_rad) * sun$sin_dec) / (cos(lat_rad) * sun$cos_dec)
    cos_hour <- pmax(-1, pmin(1, cos_hour))
    hour_angle_deg <- acos(cos_hour) * 180 / pi
    delta_minutes <- hour_angle_deg * 4
    solar_noon <- 720 - 4 * lon - sun$eqtime
    target_minutes <- solar_noon + ifelse(rise, -delta_minutes, delta_minutes)

    midnight <- as.POSIXct(
      paste0(strftime(guess, "%Y-%m-%d", tz = "UTC"), " 00:00:00"),
      tz = "UTC"
    )
    guess <- midnight + target_minutes * 60

    day_adjust <- round((as.numeric(twilight) - as.numeric(guess)) / 86400)
    guess <- guess + day_adjust * 86400
  }

  guess
}

#' Estimate the sun elevation angle for a known site
#'
#' Uses observed calibration twilights at a known location to learn the
#' sun elevation angle required by the threshold method. The calculation
#' minimizes the median absolute difference between observed and predicted
#' twilights using the NOAA solar equations.
#'
#' @param twilight POSIXct vector of twilight times from the calibration period.
#' @param rise Logical vector marking whether each event is a sunrise (TRUE) or sunset (FALSE).
#' @param lon,lat Numeric longitude and latitude of the calibration site.
#' @param interval Numeric length-two vector giving the search interval (in degrees) for the sun elevation.
#'
#' @return Named numeric vector containing the inferred zenith angle (`z1`),
#'   the sun elevation (`degElevation`), and the objective value.
#' @export
estimate_sun_elevation <- function(twilight, rise, lon, lat, interval = c(-12, 2)) {
  if (length(twilight) < 4) {
    stop("Need at least four twilight events to estimate sun elevation.")
  }

  objective <- function(elev) {
    predicted <- predict_twilight_time(twilight, lon, lat, rise, elev)
    residuals <- as.numeric(difftime(twilight, predicted, units = "mins"))
    residuals <- residuals[is.finite(residuals)]
    if (!length(residuals)) {
      return(1e6)
    }
    stats::median(abs(residuals))
  }

  opt <- stats::optimize(objective, interval = interval)
  zenith <- 90 - opt$minimum

  c(z1 = zenith, degElevation = opt$minimum, fit = opt$objective)
}

threshold_coordinates <- function(t_first, t_second, type, deg_elevation, tol = 1e-6) {
  if (!length(t_first)) {
    return(matrix(numeric(0), ncol = 2))
  }

  deg_elevation <- rep(deg_elevation, length.out = length(t_first))
  rise_time <- t_first
  rise_time[type != 1] <- t_second[type != 1]
  set_time <- t_second
  set_time[type != 1] <- t_first[type != 1]

  sun_rise <- solar_parameters(rise_time)
  sun_set <- solar_parameters(set_time)
  cos_z <- cos((90 - deg_elevation) * pi / 180)

  lon <- -(sun_rise$solar_time + sun_set$solar_time +
    ifelse(sun_rise$solar_time < sun_set$solar_time, 360, 0)) / 2
  lon <- ((lon + 180) %% 360) - 180

  latitude_from_event <- function(sun) {
    hour_angle <- (sun$solar_time + lon - 180) * pi / 180
    a <- sun$sin_dec
    b <- sun$cos_dec * cos(hour_angle)
    R <- sqrt(a^2 + b^2)
    ratio <- cos_z / R
    ratio[!is.finite(ratio)] <- NA_real_
    ratio <- pmax(-1, pmin(1, ratio))
    phi <- asin(ratio) - atan2(b, a)
    phi_deg <- phi * 180 / pi
    phi_deg[R < tol] <- NA_real_
    phi_deg
  }

  lat1 <- latitude_from_event(sun_rise)
  lat2 <- latitude_from_event(sun_set)
  lat <- rowMeans(cbind(lat1, lat2), na.rm = TRUE)

  cbind(lon, lat)
}

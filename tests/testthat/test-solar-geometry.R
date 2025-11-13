test_that("estimate_sun_elevation recovers known calibration", {
  set.seed(42)
  base_times <- as.POSIXct("2024-06-01 00:00:00", tz = "UTC") + seq(0, by = 12 * 3600, length.out = 30)
  rise_flags <- rep(c(TRUE, FALSE), length.out = length(base_times))
  synthetic <- glscalibrator:::predict_twilight_time(
    twilight = base_times,
    lon = -115,
    lat = 28,
    rise = rise_flags,
    deg_elevation = -6
  )

  est <- glscalibrator:::estimate_sun_elevation(
    twilight = synthetic,
    rise = rise_flags,
    lon = -115,
    lat = 28
  )

  sun_elev <- 90 - unname(est["z1"])
  expect_true(abs(sun_elev - (-6)) < 0.5)
})

test_that("threshold_coordinates returns plausible lat/lon", {
  timeline <- as.POSIXct("2024-05-01 00:00:00", tz = "UTC") + seq(0, by = 12 * 3600, length.out = 40)
  rise_flags <- rep(c(TRUE, FALSE), length.out = length(timeline))
  synthetic <- glscalibrator:::predict_twilight_time(
    twilight = timeline,
    lon = -70,
    lat = 45,
    rise = rise_flags,
    deg_elevation = -7
  )
  t_first <- synthetic[-length(synthetic)]
  t_second <- synthetic[-1]
  type <- ifelse(rise_flags[-length(rise_flags)], 1, 2)

  coords <- glscalibrator:::threshold_coordinates(
    t_first = t_first,
    t_second = t_second,
    type = type,
    deg_elevation = -7
  )

  expect_true(all(is.finite(coords[, 1])))
  expect_true(all(is.finite(coords[, 2])))
  expect_equal(median(coords[, 1]), -70, tolerance = 5)
  expect_equal(median(coords[, 2]), 45, tolerance = 5)
})

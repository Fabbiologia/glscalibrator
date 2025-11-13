test_that("read_lux_file reads valid file", {
  # This is a placeholder test
  # In practice, you would include example .lux files in inst/extdata/

  expect_error(
    read_lux_file("nonexistent_file.lux"),
    "File does not exist"
  )
})

test_that("detect_twilights requires correct columns", {
  bad_data <- data.frame(x = 1:10, y = 1:10)

  expect_error(
    detect_twilights(bad_data),
    "must have 'Date' and 'Light' columns"
  )
})

test_that("detect_twilights identifies transitions in well-formed light data", {
  timestamps <- as.POSIXct("2024-01-01 00:00:00", tz = "UTC") + seq(0, by = 3600, length.out = 72)
  light_pattern <- rep(c(rep(0.5, 6), rep(4, 6)), length.out = length(timestamps))
  light_data <- data.frame(Date = timestamps, Light = light_pattern)

  twilight_events <- detect_twilights(light_data, threshold = 2)

  expect_true(is.data.frame(twilight_events))
  expect_true(nrow(twilight_events) > 0)
  expect_true(all(c("Twilight", "Rise") %in% names(twilight_events)))
  expect_true(all(diff(twilight_events$Twilight) > 0))
})

test_that("auto_detect_calibration returns a valid calibration window", {
  timestamps <- as.POSIXct("2024-01-01 00:00:00", tz = "UTC") + seq(0, by = 3600, length.out = 240)
  light_pattern <- rep(c(rep(0.5, 6), rep(4, 6)), length.out = length(timestamps))
  light_data <- data.frame(Date = timestamps, Light = light_pattern)

  calibration <- auto_detect_calibration(
    light_data = light_data,
    colony_lat = 27.85,
    colony_lon = -115.17,
    threshold = 2,
    min_twilights = 4
  )

  expect_equal(calibration$start, min(light_data$Date))
  expect_equal(calibration$duration_days, 2)
  expect_gte(calibration$twilights, 4)
  expect_true(calibration$end > calibration$start)
})

test_that("filter_twilights returns data.frame", {
  # Create mock twilight data
  twilights <- data.frame(
    Twilight = as.POSIXct("2024-01-01 06:00:00", tz = "UTC") + 43200 * (0:10),
    Rise = rep(c(TRUE, FALSE), length.out = 11)
  )

  result <- filter_twilights(twilights, threshold = 2, strict = TRUE)

  expect_true(is.data.frame(result))
  expect_true("Twilight" %in% colnames(result))
  expect_true("Rise" %in% colnames(result))
})

test_that("filter_twilights removes twilights that are too close together", {
  twilight_times <- as.POSIXct("2024-01-01 00:00:00", tz = "UTC") + c(0, 1800, 3600, 10800)
  twilights <- data.frame(
    Twilight = twilight_times,
    Rise = c(TRUE, FALSE, TRUE, FALSE)
  )

  filtered <- filter_twilights(twilights, threshold = 2, strict = TRUE)

  gaps_secs <- as.numeric(diff(filtered$Twilight), units = "secs")
  expect_true(all(gaps_secs >= 3600))
})

test_that("convert_to_glsmerge produces GLSmerge-compatible structure", {
  results <- data.frame(
    bird_id = "bird_001",
    datetime = as.POSIXct("2024-01-01 00:00:00", tz = "UTC") + c(0, 86400, 172800),
    date = as.Date("2024-01-01") + 0:2,
    Longitude = c(-120.5, -121.2, -119.9),
    Latitude = c(30.2, 31.1, 29.8),
    sun_elevation = c(6.5, 6.5, 6.5),
    zenith = c(93.5, 93.5, 93.5),
    method = "threshold_crossing_internal_gamma"
  )

  glsmerge_df <- convert_to_glsmerge(results, bird_id = "bird_001", zenith = 93.5)

  expect_equal(nrow(glsmerge_df), nrow(results))
  expect_true(all(c("Index", "GLS", "Longitude", "Latitude", "Type") %in% names(glsmerge_df)))
  expect_equal(unique(glsmerge_df$GLS), "bird")
  expect_true(all(glsmerge_df$Index == seq_len(nrow(results))))
})

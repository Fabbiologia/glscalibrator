test_that("probgls_config builds with expected prob_algorithm names", {
  cfg <- probgls_config(
    tagging_location = c(-115.174, 27.852),
    boundary_box     = c(-140, -80, 0, 55),
    NOAA_OI_location = tempdir()
  )
  expect_s3_class(cfg, "probgls_config")
  # names must mirror prob_algorithm's dotted arguments
  expect_true(all(c("particle.number", "speed.wet", "speed.dry", "sst.sd",
                    "land.mask", "boundary.box", "NOAA.OI.location") %in% names(cfg)))
  expect_length(cfg[["tagging.location"]], 2)
  expect_length(cfg[["speed.wet"]], 3)
})

test_that("validation catches missing/ill-formed runtime fields", {
  bad <- probgls_config()               # no location / box / env folder
  expect_error(validate_probgls_config(bad, require_runtime = TRUE))
  # structural checks still pass without runtime requirements
  expect_invisible(validate_probgls_config(bad, require_runtime = FALSE))

  bad2 <- probgls_config(tagging_location = c(-115.174, 27.852),
                         boundary_box = c(-140, -80, 0, 55),
                         NOAA_OI_location = tempdir())
  bad2[["speed.wet"]] <- c(1, 2)        # wrong length
  expect_error(validate_probgls_config(bad2, require_runtime = TRUE))
})

test_that("config round-trips through YAML", {
  skip_if_not_installed("yaml")
  cfg <- probgls_config(tagging_location = c(-115.174, 27.852),
                        boundary_box = c(-140, -80, 0, 55),
                        NOAA_OI_location = tempdir(),
                        speed_wet = c(1, 1.3, 5))
  f <- tempfile(fileext = ".yml")
  write_probgls_config(cfg, f)
  cfg2 <- read_probgls_config(f)
  expect_equal(cfg2[["speed.wet"]], c(1, 1.3, 5))
  expect_equal(cfg2[["tagging.location"]], c(-115.174, 27.852))
})

test_that("prepare_trn pairs twilights into tFirst/tSecond/type", {
  tw <- data.frame(
    Twilight = as.POSIXct("2023-06-16 06:00", tz = "UTC") + (0:3) * 6 * 3600,
    Rise     = c(TRUE, FALSE, TRUE, FALSE)
  )
  trn <- prepare_trn(tw)
  expect_equal(nrow(trn), 3)
  expect_equal(trn$type, c(1L, 2L, 1L))
  expect_true(all(trn$tSecond > trn$tFirst))
})

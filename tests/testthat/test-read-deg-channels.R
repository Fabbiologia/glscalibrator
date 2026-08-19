# Regression tests for the 0.2.1 fix: a Migrate ".deg" file holds WET/DRY
# immersion, not temperature. It must never be returned as `Temp`.

make_deg <- function(header, rows) {
  f <- tempfile(fileext = ".deg")
  writeLines(c("Migrate Technology Ltd logger", "Logger number: TEST", "",
               "MODE: 6B (light, wet/dry recorded)", header, rows), f)
  f
}

test_that("wets0-20 layout is read as a wet count, not temperature", {
  f <- make_deg("DD/MM/YYYY HH:MM:SS\twets0-20",
                c("16/06/2023 06:31:02\t0", "16/06/2023 06:41:02\t14",
                  "16/06/2023 06:51:02\t20"))
  d <- read_deg_file(f)
  expect_identical(attr(d, "channel"), "wet_count")
  expect_true("wet_raw" %in% names(d))
  expect_false("Temp" %in% names(d))      # the 0.2.0 bug
  expect_equal(d$wet_raw, c(0, 14, 20))
})

test_that("duration + wet/dry bout layout is recognised", {
  f <- make_deg("DD/MM/YYYY HH:MM:SS\tduration\twet/dry",
                c("28/04/2016 10:50:01\t1360146\tdry",
                  "28/04/2016 10:50:13\t12\twet",
                  "28/04/2016 10:50:49\t36\tdry"))
  d <- read_deg_file(f)
  expect_identical(attr(d, "channel"), "wet_bout")
  expect_true(all(c("duration", "wet_raw") %in% names(d)))
  expect_false("Temp" %in% names(d))
  expect_equal(d$wet_raw, c("dry", "wet", "dry"))
})

test_that("a genuine temperature column is still read as temperature", {
  f <- make_deg("DD/MM/YYYY HH:MM:SS\ttemperature",
                c("16/06/2023 06:31:02\t17.5", "16/06/2023 06:41:02\t18.25"))
  d <- read_deg_file(f)
  expect_identical(attr(d, "channel"), "temperature")
  expect_equal(d$Temp, c(17.5, 18.25))
})

test_that("deduce_sst refuses a wet/dry .deg instead of misreading it", {
  f <- make_deg("DD/MM/YYYY HH:MM:SS\twets0-20",
                c("16/06/2023 06:31:02\t0", "16/06/2023 06:41:02\t14"))
  dep <- list(id = "TEST", light = NULL, temperature = read_deg_file(f),
              wetdry = NULL, sst_raw = NULL)
  class(dep) <- c("gls_deployment", "list")
  expect_error(deduce_sst(dep), "no usable temperature channel")
})

test_that("read_probgls_params ingests the shipped example sheet", {
  f <- system.file("extdata", "probgls_params_example.csv", package = "glscalibrator")
  skip_if(f == "", "example sheet not installed")
  cfg <- suppressWarnings(read_probgls_params(f, quiet = TRUE))

  expect_s3_class(cfg, "probgls_config")
  # expert-supplied values land in the config
  expect_equal(cfg[["range.solar"]], c(-6, -2))
  expect_equal(cfg[["sst.sd"]], 1)
  expect_equal(cfg[["speed.dry"]], c(3.63, 4.16, 6.96))
  expect_true(cfg[["land.mask"]])
  # rows holding formulas / blanks keep the package defaults
  expect_equal(cfg[["particle.number"]], 2000)

  # (lat, lon) slip repaired -> (lon, lat)
  tl <- cfg[["tagging.location"]]
  expect_lt(tl[1], -90)
  expect_lte(abs(tl[2]), 90)

  # interleaved boundary box resolved to c(xmin, xmax, ymin, ymax)
  bb <- cfg[["boundary.box"]]
  expect_lte(bb[1], bb[2]); expect_lte(bb[3], bb[4])
  expect_true(all(abs(bb[3:4]) <= 90))
  # decisive property: the box must contain its own deployment site
  expect_true(tl[1] >= bb[1] && tl[1] <= bb[2] && tl[2] >= bb[3] && tl[2] <= bb[4])
})

test_that("boundary-box inference handles the orderings sheets use", {
  inf <- glscalibrator:::.infer_boundary_box
  colony <- c(-115.174, 27.852)
  # already canonical -> untouched
  expect_equal(inf(c(-140, -80, 0, 55), colony), c(-140, -80, 0, 55))
  # interleaved (lat, lon, lat, lon)
  expect_equal(inf(c(7, -78, 48, -131), colony), c(-131, -78, 7, 48))
  # lat pair first
  expect_equal(inf(c(7, 48, -131, -78), colony), c(-131, -78, 7, 48))
  # unsorted within pairs
  expect_equal(inf(c(-80, -140, 55, 0), colony), c(-140, -80, 0, 55))
})

test_that("cell parser handles the value styles found in real sheets", {
  p <- glscalibrator:::.parse_sheet_value
  expect_equal(p("c(-6,-2)"), c(-6, -2))
  expect_true(p("T")); expect_true(p("TRUE"))
  expect_false(p("FALSE"))
  expect_equal(p('"ellipsoid"'), "ellipsoid")
  expect_equal(p("0.08"), 0.08)
  expect_null(p("min(trn$tFirst)"))   # formulas are not literals
  expect_null(p("NaN")); expect_null(p(""))
})

test_that("suspect speed ordering is flagged but not silently changed", {
  f <- system.file("extdata", "probgls_params_example.csv", package = "glscalibrator")
  skip_if(f == "", "example sheet not installed")
  expect_warning(read_probgls_params(f, quiet = TRUE), "speed.wet")
  cfg <- suppressWarnings(read_probgls_params(f, quiet = TRUE))
  expect_equal(cfg[["speed.wet"]], c(1.27, 2.47, 1.71))  # used as given
})

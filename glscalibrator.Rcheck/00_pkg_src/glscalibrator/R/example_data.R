#' Metadata for the bundled GLS example datasets
#'
#' The package ships with three light-level geolocation (.lux) files that are
#' used throughout the documentation, vignettes, and tests. This metadata table
#' records their origin and recommended use so that analysts can reference the
#' contents programmatically.
#'
#' @format A data frame with 3 rows and 7 variables:
#' \describe{
#'   \item{name}{Short identifier used by \code{gls_example()}}
#'   \item{file}{Filename stored under \code{inst/extdata/}}
#'   \item{type}{"real" or "synthetic" dataset}
#'   \item{description}{Summary of the dataset contents}
#'   \item{duration_days}{Approximate deployment duration represented}
#'   \item{size_kb}{Approximate file size in kilobytes}
#'   \item{notes}{Additional guidance for analysis and demonstrations}
#' }
#'
#' @details
#' All files are plain-text .lux exports that can be read directly with
#' \code{read_lux_file()}. Real datasets were collected from tropical seabirds
#' breeding near 27.85°N, 115.17°W and are approved for demonstration and
#' teaching purposes. The synthetic dataset contains idealised sunrise/sunset
#' curves for rapid testing.
#'
#' @seealso \code{gls_example()}, \code{list_gls_examples()}
#' @keywords datasets
#' @docType data
#' @name glscalibrator_example_metadata
NULL

#' @rdname glscalibrator_example_metadata
#' @usage glscalibrator_example_metadata
#' @format A data frame (tibble) with metadata for each example dataset.
#' @export
glscalibrator_example_metadata <- data.frame(
  name = c("W086", "W592", "synthetic"),
  file = c(
    "W086_24May17_215116.lux",
    "W592_24May17_211818.lux",
    "synthetic_example.lux"
  ),
  type = c("real", "real", "synthetic"),
  description = c(
    "Clean colony deployment with clear day/night cycles",
    "Longer colony deployment capturing seasonal variation",
    "Simulated light curve for quick twilight detection tests"
  ),
  duration_days = c(34, 126, 2),
  size_kb = c(207, 898, 9),
  notes = c(
    "Recommended for illustrating calibration period detection",
    "Useful for stress-testing batch processing workflows",
    "Ideal for unit tests and teaching threshold tuning"
  ),
  stringsAsFactors = FALSE
)

#' @title Bundled GLS example filenames
#' @description Named character vector of the filenames stored in
#'   \code{inst/extdata/}, keyed by the identifiers recognised by
#'   \code{gls_example()}.
#' @rdname glscalibrator_example_metadata
#' @usage glscalibrator_example_files
#' @format Named character vector. Use with \code{system.file("extdata", ...)}.
#' @export
glscalibrator_example_files <- stats::setNames(
  glscalibrator_example_metadata$file,
  glscalibrator_example_metadata$name
)

#' Get Path to Example Data
#'
#' Helper function to get the path to example .lux files included with the package.
#' Three example files are available and their metadata is exposed via
#' \code{glscalibrator_example_metadata}.
#'
#' @param which Character string specifying which example file:
#'   \itemize{
#'     \item "W086" - See metadata for details
#'     \item "W592" - See metadata for details
#'     \item "synthetic" - See metadata for details
#'     \item "all" - Returns paths to all example files (default)
#'   }
#'
#' @return Character vector of file path(s) to example data
#'
#' @examples
#' # Inspect available example datasets
#' list_gls_examples()
#'
#' # Read the bundled W086 seabird deployment
#' light_data <- read_lux_file(gls_example("W086"))
#'
#' # Run calibration on the synthetic dataset (quick demo)
#' synt_path <- gls_example("synthetic")
#' synthetic_data <- read_lux_file(synt_path)
#' twl <- detect_twilights(synthetic_data, threshold = 2)
#'
#' @export
gls_example <- function(which = "all") {

  if (which == "all") {
    paths <- system.file("extdata", glscalibrator_example_files, package = "glscalibrator")
    names(paths) <- names(glscalibrator_example_files)
    return(paths)
  }

  if (!which %in% names(glscalibrator_example_files)) {
    stop("Unknown example. Choose from: ", paste(names(glscalibrator_example_files), collapse = ", "))
  }

  path <- system.file("extdata", glscalibrator_example_files[[which]], package = "glscalibrator")

  if (path == "") {
    stop("Example file not found. Package may not be properly installed.")
  }

  return(path)
}


#' List Available Example Datasets
#'
#' Shows information about example datasets included with the package.
#'
#' @return A data.frame with columns: \code{name}, \code{file}, \code{type},
#'   \code{description}, \code{duration_days}, \code{size_kb}, \code{notes}
#'
#' @examples
#' list_gls_examples()
#'
#' @export
list_gls_examples <- function() {
  glscalibrator_example_metadata
}

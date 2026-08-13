#' Acquire environmental fields for the particle model
#'
#' The particle model constrains latitude by matching logged SST to satellite
#' SST, and uses sea-ice and a land mask. This helper prepares the environmental
#' folder that \code{\link{probgls_config}}'s \code{NOAA.OI.location} points to,
#' downloading NOAA Optimum Interpolation SST V2.1 (and optionally sea-ice)
#' daily fields covering a deployment's date span.
#'
#' The land mask itself is supplied internally by \code{probGLS}; only the
#' time-varying SST / ice fields need to be fetched here.
#'
#' @param dates A vector of dates (or POSIXct) spanning the deployment(s); only
#'   the min/max years are used to decide which annual files to fetch.
#' @param dest Destination folder (created if needed). Returned invisibly.
#' @param variables Character vector, any of \code{"sst"}, \code{"icec"}.
#' @param source Base URL of the NOAA PSL OISST v2.1 high-res archive.
#' @param overwrite Logical, re-download files that already exist.
#'
#' @return \code{dest}, invisibly. Suitable to pass as
#'   \code{NOAA_OI_location} to \code{\link{probgls_config}}.
#'
#' @details Downloads annual NetCDF files \code{sst.day.mean.YYYY.nc} (and
#'   \code{icec.day.mean.YYYY.nc}). These are large (hundreds of MB per year);
#'   fetch once and reuse. Requires internet access and the \code{curl} package.
#'
#' @examples
#' \dontrun{
#' env <- get_environmental_data(
#'   dates = as.Date(c("2023-06-01", "2024-05-01")),
#'   dest  = "results/oisst")
#' cfg <- probgls_config(tagging_location = c(-115.174, 27.852),
#'                       boundary_box = c(-140, -80, 0, 55),
#'                       NOAA_OI_location = env)
#' }
#' @export
get_environmental_data <- function(dates,
                                    dest,
                                    variables = c("sst", "icec"),
                                    source = "https://downloads.psl.noaa.gov/Datasets/noaa.oisst.v2.highres",
                                    overwrite = FALSE) {
  variables <- match.arg(variables, several.ok = TRUE)
  if (!requireNamespace("curl", quietly = TRUE))
    stop("Package 'curl' is required to download environmental data.")
  dir.create(dest, recursive = TRUE, showWarnings = FALSE)

  yrs <- sort(unique(as.integer(format(as.Date(dates), "%Y"))))
  for (v in variables) {
    for (y in yrs) {
      fn  <- sprintf("%s.day.mean.%d.nc", v, y)
      out <- file.path(dest, fn)
      if (file.exists(out) && !overwrite) {
        message("cached: ", fn); next
      }
      url <- file.path(source, fn)
      message("downloading: ", url)
      ok <- tryCatch({ curl::curl_download(url, out, quiet = FALSE); TRUE },
                     error = function(e) { message("  failed: ", conditionMessage(e)); FALSE })
      if (!ok && file.exists(out)) unlink(out)
    }
  }
  message("Environmental data ready in: ", normalizePath(dest))
  invisible(dest)
}

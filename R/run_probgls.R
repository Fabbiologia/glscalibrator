#' Reconstruct a most-probable track with the probGLS particle model
#'
#' Runs \code{probGLS::prob_algorithm()} from a validated
#' \code{\link{probgls_config}}, injecting the run-time inputs (twilights,
#' deduced SST sensor, wet/dry activity) and the derived deployment dates and
#' twilight-error terms. Unlike the raw threshold positions, the returned track
#' is constrained by SST, a movement/speed prior and a land mask, and carries
#' per-step credible intervals.
#'
#' The wrapper is version-safe: it passes only the arguments the installed
#' \code{prob_algorithm()} actually declares, so it keeps working if probGLS
#' adds or renames parameters.
#'
#' @param trn A GeoLight-style twilight data.frame with columns \code{tFirst},
#'   \code{tSecond}, \code{type} (see \code{\link{prepare_trn}}).
#' @param sensor SST sensor data.frame from \code{\link{deduce_sst}} (columns
#'   \code{dtime}, \code{SST}, \code{SST.remove}).
#' @param config A \code{\link{probgls_config}} object.
#' @param act Optional wet/dry activity data.frame (\code{Date}, \code{wet}).
#' @param sunrise_sd,sunset_sd Optional length-3 twilight error terms; if
#'   \code{NULL} and not already in \code{config}, they are estimated with
#'   \code{probGLS::twilight_error_estimation()}.
#'
#' @return A list of class \code{"probgls_result"}:
#'   \item{model}{the full object returned by \code{prob_algorithm()}}
#'   \item{track}{tidy data.frame of the most-probable track (see
#'     \code{\link{tidy_probgls_track}})}
#'   \item{config}{the resolved configuration actually used}
#'
#' @seealso \code{\link{run_gls_pipeline}}, \code{\link{deduce_sst}},
#'   \code{\link{get_environmental_data}}
#' @examples
#' \dontrun{
#' res <- run_probgls(trn, sensor, cfg, act = dep$wetdry)
#' head(res$track)
#' }
#' @export
run_probgls <- function(trn, sensor, config, act = NULL,
                        sunrise_sd = NULL, sunset_sd = NULL) {

  if (!requireNamespace("probGLS", quietly = TRUE))
    stop("Package 'probGLS' is required. ",
         "install: remotes::install_github('benjamin-merkel/probGLS').")
  validate_probgls_config(config, require_runtime = TRUE)

  cfg <- config
  # --- derive deployment dates if not set ---
  if (is.null(cfg[["tagging.date"]]))   cfg[["tagging.date"]]   <- min(trn$tFirst,  na.rm = TRUE)
  if (is.null(cfg[["retrieval.date"]])) cfg[["retrieval.date"]] <- max(trn$tSecond, na.rm = TRUE)

  # --- twilight error terms ---
  sr <- sunrise_sd %||% cfg[["sunrise.sd"]]
  ss <- sunset_sd  %||% cfg[["sunset.sd"]]
  if (is.null(sr) || is.null(ss)) {
    if (exists("twilight_error_estimation", where = asNamespace("probGLS"))) {
      te <- probGLS::twilight_error_estimation()
      sr <- ss <- te
    } else {
      sr <- ss <- c(2.49, 0.94, 0.15)   # documented default
    }
  }
  cfg[["sunrise.sd"]] <- sr
  cfg[["sunset.sd"]]  <- ss

  # --- inject run-time inputs ---
  cfg[["trn"]]    <- trn
  cfg[["sensor"]] <- sensor
  cfg[["act"]]    <- act

  # --- call prob_algorithm with only the args it declares (version-safe) ---
  fmls <- names(formals(probGLS::prob_algorithm))
  call_args <- cfg[intersect(names(cfg), fmls)]
  dropped <- setdiff(names(cfg), fmls)
  if (length(dropped))
    message("Note: config fields not used by this probGLS version: ",
            paste(dropped, collapse = ", "))

  model <- do.call(probGLS::prob_algorithm, call_args)
  track <- tidy_probgls_track(model)

  out <- list(model = model, track = track, config = cfg)
  class(out) <- c("probgls_result", "list")
  out
}

#' Tidy the most-probable track out of a probGLS model object
#'
#' Extracts a flat data.frame from the (list) object returned by
#' \code{prob_algorithm()}, robust to element-naming differences across probGLS
#' versions.
#'
#' @param model A probGLS model object (or a \code{"probgls_result"}).
#' @return data.frame with at least \code{datetime}, \code{lon}, \code{lat};
#'   longitude/latitude credible bounds are included when present.
#' @export
tidy_probgls_track <- function(model) {
  if (inherits(model, "probgls_result")) model <- model$model
  # prob_algorithm returns a list; the median/most-probable track is commonly
  # the first element (an sf/data.frame). Handle both.
  mp <- NULL
  if (is.list(model)) {
    nm <- names(model)
    cand <- c("most probable track", "geographic_median", "track")
    hit <- intersect(cand, nm)
    mp <- if (length(hit)) model[[hit[1]]] else model[[1]]
  } else mp <- model

  if (inherits(mp, "sf")) {
    if (requireNamespace("sf", quietly = TRUE)) {
      xy <- sf::st_coordinates(mp)
      df <- sf::st_drop_geometry(mp)
      df$lon <- xy[, 1]; df$lat <- xy[, 2]
      mp <- df
    }
  }
  mp <- as.data.frame(mp)

  # normalise common column names
  ren <- function(from, to) {
    j <- which(tolower(names(mp)) %in% from)[1]
    if (!is.na(j)) names(mp)[j] <<- to
  }
  ren(c("dtime", "datetime", "date"), "datetime")
  ren(c("lon", "longitude", "x", "median_lon"), "lon")
  ren(c("lat", "latitude", "y", "median_lat"),  "lat")
  mp
}

#' Build, validate and store a probGLS pipeline configuration
#'
#' The movement-model stage of the pipeline is driven entirely by a
#' configuration object so that no biology is hard-coded and the package stays
#' taxon-agnostic. The object mirrors, one-to-one, the arguments of
#' \code{probGLS::prob_algorithm()} (the 29 components documented in the
#' project spec sheet). Arguments that are derived automatically by the pipeline
#' (\code{trn}, \code{sensor}, \code{act}, \code{tagging.date},
#' \code{retrieval.date}, \code{sunrise.sd}, \code{sunset.sd}) may be left
#' \code{NULL} and are filled in at run time.
#'
#' Defaults follow the general-purpose values recommended for probGLS and are
#' \emph{not} specific to any species. Override them per deployment.
#'
#' @param tagging_location Numeric length-2 \code{c(lon, lat)} of the
#'   deployment (colony / capture) location. Required.
#' @param boundary_box Numeric length-4 \code{c(xmin, xmax, ymin, ymax)}
#'   spatial bounds of plausible movement, in decimal degrees. Required.
#' @param NOAA_OI_location Character path to the folder holding the
#'   environmental fields (NOAA OI SST, sea-ice, land mask) prepared by
#'   \code{\link{get_environmental_data}}. Required to run the particle model.
#' @param particle_number,iteration_number Integer particle and iteration counts.
#' @param loess_quartile Numeric loess light-smoothing quartiles, or \code{NULL}.
#' @param tagging_date,retrieval_date Deployment start / end
#'   (\code{POSIXct}/\code{Date}); \code{NULL} = derive from the twilights.
#' @param sunrise_sd,sunset_sd Numeric length-3 twilight-error terms, or
#'   \code{NULL} to estimate them from the calibration twilights.
#' @param tol Numeric tolerance on solar declination.
#' @param range_solar Numeric length-2 min/max solar angle window.
#' @param speed_dry,speed_wet Numeric length-3 \code{c(optimal, sd, max)} travel
#'   speeds (m/s) while the logger is dry / wet.
#' @param distance_method Character distance model, e.g. \code{"ellipsoid"}.
#' @param sst_sd Numeric SST error (deg C).
#' @param max_sst_diff Numeric maximum allowed \code{|tag SST - satellite SST|}.
#' @param ice_conc_cutoff Numeric sea-ice concentration cutoff (percent).
#' @param east_west_comp Logical, apply east-west (longitude) compensation.
#' @param land_mask Logical, restrict positions to sea (\code{TRUE}) or allow
#'   land (\code{FALSE}); \code{NULL} passes through unchanged.
#' @param med_sea,black_sea,baltic_sea,caspian_sea Logical, treat these enclosed
#'   seas as land.
#' @param wetdry_resolution Numeric conductivity sampling resolution (seconds).
#' @param backward Logical, run the algorithm from end to start.
#' @param preset Optional character naming a starting preset. Currently
#'   \code{"seabird"} (the documented general defaults). Explicit arguments
#'   always override the preset.
#'
#' @return An object of class \code{"probgls_config"}: a named list whose names
#'   are exactly the \code{probGLS::prob_algorithm()} argument names (dotted).
#'
#' @seealso \code{\link{run_probgls}}, \code{\link{run_gls_pipeline}},
#'   \code{\link{read_probgls_config}}, \code{\link{write_probgls_config}}
#'
#' @examples
#' cfg <- probgls_config(
#'   tagging_location = c(-115.174, 27.852),
#'   boundary_box     = c(-140, -80, 0, 55),
#'   NOAA_OI_location = tempdir()
#' )
#' cfg[["speed.wet"]]
#'
#' @export
probgls_config <- function(tagging_location = NULL,
                           boundary_box     = NULL,
                           NOAA_OI_location = NULL,
                           particle_number  = 2000,
                           iteration_number = 100,
                           loess_quartile   = NULL,
                           tagging_date     = NULL,
                           retrieval_date   = NULL,
                           sunrise_sd       = NULL,
                           sunset_sd        = NULL,
                           tol              = 0.08,
                           range_solar      = c(-7, -1),
                           speed_dry        = c(12, 6, 45),
                           speed_wet        = c(1, 1.3, 5),
                           distance_method  = "ellipsoid",
                           sst_sd           = 0.5,
                           max_sst_diff     = 3,
                           ice_conc_cutoff  = 1,
                           east_west_comp   = TRUE,
                           land_mask        = TRUE,
                           med_sea          = FALSE,
                           black_sea        = FALSE,
                           baltic_sea       = FALSE,
                           caspian_sea      = FALSE,
                           wetdry_resolution = 1,
                           backward         = FALSE,
                           preset           = c("seabird")) {

  preset <- match.arg(preset)

  cfg <- list(
    particle.number            = particle_number,
    iteration.number           = iteration_number,
    loess.quartile             = loess_quartile,
    tagging.location           = tagging_location,
    tagging.date               = tagging_date,
    retrieval.date             = retrieval_date,
    sunrise.sd                 = sunrise_sd,
    sunset.sd                  = sunset_sd,
    tol                        = tol,
    range.solar                = range_solar,
    speed.dry                  = speed_dry,
    speed.wet                  = speed_wet,
    distance.method            = distance_method,
    sst.sd                     = sst_sd,
    max.sst.diff               = max_sst_diff,
    ice.conc.cutoff            = ice_conc_cutoff,
    boundary.box               = boundary_box,
    east.west.comp             = east_west_comp,
    land.mask                  = land_mask,
    med.sea                    = med_sea,
    black.sea                  = black_sea,
    baltic.sea                 = baltic_sea,
    caspian.sea                = caspian_sea,
    sensor                     = NULL,   # filled by pipeline (deduced SST)
    trn                        = NULL,   # filled by pipeline (twilights)
    act                        = NULL,   # filled by pipeline (wet/dry)
    wetdry.resolution          = wetdry_resolution,
    backward                   = backward,
    NOAA.OI.location           = NOAA_OI_location
  )
  class(cfg) <- c("probgls_config", "list")
  cfg
}

#' @rdname probgls_config
#' @param x A \code{probgls_config} object.
#' @param require_runtime Logical; if \code{TRUE}, also require the fields that
#'   are needed to actually launch the particle model
#'   (\code{tagging.location}, \code{boundary.box}, \code{NOAA.OI.location}).
#' @return \code{validate_probgls_config()} returns \code{x} invisibly on
#'   success and stops with an informative error otherwise.
#' @export
validate_probgls_config <- function(x, require_runtime = TRUE) {
  if (!inherits(x, "probgls_config"))
    stop("`x` must be a `probgls_config` object (see ?probgls_config).")

  chk <- function(cond, msg) if (!isTRUE(cond)) stop(msg, call. = FALSE)

  len3 <- c("speed.dry", "speed.wet")
  for (f in len3)
    chk(is.numeric(x[[f]]) && length(x[[f]]) == 3,
        sprintf("`%s` must be numeric length 3 c(optimal, sd, max).", f))

  chk(length(x[["range.solar"]]) == 2, "`range.solar` must be length 2 c(min, max).")
  chk(is.numeric(x[["particle.number"]]) && x[["particle.number"]] > 0,
      "`particle.number` must be a positive integer.")

  if (require_runtime) {
    chk(is.numeric(x[["tagging.location"]]) && length(x[["tagging.location"]]) == 2,
        "`tagging.location` must be numeric c(lon, lat). Set it per deployment.")
    chk(is.numeric(x[["boundary.box"]]) && length(x[["boundary.box"]]) == 4,
        "`boundary.box` must be numeric c(xmin, xmax, ymin, ymax).")
    chk(!is.null(x[["NOAA.OI.location"]]) && dir.exists(x[["NOAA.OI.location"]]),
        "`NOAA.OI.location` must point to an existing environmental-data folder (see ?get_environmental_data).")
  }
  invisible(x)
}

#' @rdname probgls_config
#' @param ... Ignored.
#' @export
print.probgls_config <- function(x, ...) {
  cat("<probgls_config>  (mirrors probGLS::prob_algorithm arguments)\n")
  runtime <- c("trn", "sensor", "act")
  for (nm in names(x)) {
    v <- x[[nm]]
    show <- if (is.null(v)) {
      if (nm %in% runtime) "<derived at run time>" else "NULL"
    } else if (is.data.frame(v)) sprintf("<data.frame %d x %d>", nrow(v), ncol(v))
    else paste(format(v), collapse = ", ")
    cat(sprintf("  %-18s : %s\n", nm, show))
  }
  invisible(x)
}

#' Read / write a probGLS configuration from YAML
#'
#' Persist a \code{\link{probgls_config}} so a deployment's settings are
#' reproducible and shareable. A ready-to-edit template ships with the package:
#' \code{system.file("extdata", "probgls_config_template.yml", package = "glscalibrator")}.
#'
#' @param path Path to a YAML file.
#' @return \code{read_probgls_config()} returns a \code{probgls_config};
#'   \code{write_probgls_config()} returns \code{path} invisibly.
#' @examples
#' \dontrun{
#' cfg <- read_probgls_config(
#'   system.file("extdata", "probgls_config_template.yml", package = "glscalibrator"))
#' }
#' @export
read_probgls_config <- function(path) {
  if (!requireNamespace("yaml", quietly = TRUE))
    stop("Package 'yaml' is required to read config files. install.packages('yaml').")
  raw <- yaml::read_yaml(path)
  # map dotted names -> function arguments
  arg <- function(k) raw[[k]]
  probgls_config(
    tagging_location  = arg("tagging.location"),
    boundary_box      = arg("boundary.box"),
    NOAA_OI_location  = arg("NOAA.OI.location"),
    particle_number   = arg("particle.number") %||% 2000,
    iteration_number  = arg("iteration.number") %||% 100,
    loess_quartile    = arg("loess.quartile"),
    tol               = arg("tol") %||% 0.08,
    range_solar       = arg("range.solar") %||% c(-7, -1),
    speed_dry         = arg("speed.dry") %||% c(12, 6, 45),
    speed_wet         = arg("speed.wet") %||% c(1, 1.3, 5),
    distance_method   = arg("distance.method") %||% "ellipsoid",
    sst_sd            = arg("sst.sd") %||% 0.5,
    max_sst_diff      = arg("max.sst.diff") %||% 3,
    ice_conc_cutoff   = arg("ice.conc.cutoff") %||% 1,
    east_west_comp    = arg("east.west.comp") %||% TRUE,
    land_mask         = arg("land.mask") %||% TRUE,
    med_sea           = arg("med.sea") %||% FALSE,
    black_sea         = arg("black.sea") %||% FALSE,
    baltic_sea        = arg("baltic.sea") %||% FALSE,
    caspian_sea       = arg("caspian.sea") %||% FALSE,
    wetdry_resolution = arg("wetdry.resolution") %||% 1,
    backward          = arg("backward") %||% FALSE
  )
}

#' @rdname read_probgls_config
#' @param config A \code{probgls_config} object.
#' @export
write_probgls_config <- function(config, path) {
  validate_probgls_config(config, require_runtime = FALSE)
  if (!requireNamespace("yaml", quietly = TRUE))
    stop("Package 'yaml' is required to write config files. install.packages('yaml').")
  drop <- c("trn", "sensor", "act")             # never serialise run-time data
  yaml::write_yaml(config[setdiff(names(config), drop)], path)
  invisible(path)
}

# small null-coalescing helper (internal)
`%||%` <- function(a, b) if (is.null(a)) b else a

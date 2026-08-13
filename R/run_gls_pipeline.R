#' Convert detected twilights to a GeoLight-style trn table
#'
#' Bridges the package's twilight output (a table of twilight events with a
#' logical \code{Rise} column) to the paired \code{tFirst}/\code{tSecond}/
#' \code{type} format consumed by the particle model.
#'
#' @param twilights A data.frame of twilight events with a POSIXct time column
#'   (named \code{Twilight}, \code{tFirst} or \code{Date}) and a logical
#'   sunrise indicator (named \code{Rise} or \code{sunrise}).
#' @return data.frame(\code{tFirst}, \code{tSecond}, \code{type}); \code{type}
#'   is \code{1} when \code{tFirst} is a sunrise and \code{2} when it is a sunset.
#' @export
prepare_trn <- function(twilights) {
  tcol <- intersect(c("Twilight", "tFirst", "Date", "datetime"), names(twilights))[1]
  rcol <- intersect(c("Rise", "sunrise", "Rise."), names(twilights))[1]
  if (is.na(tcol) || is.na(rcol))
    stop("`twilights` needs a time column (Twilight/tFirst/Date) and a Rise column.")

  tw <- twilights[order(twilights[[tcol]]), ]
  tt <- tw[[tcol]]; rise <- as.logical(tw[[rcol]])
  n <- length(tt)
  if (n < 2) stop("Need at least two twilight events to build trn.")

  data.frame(
    tFirst  = tt[-n],
    tSecond = tt[-1],
    type    = ifelse(rise[-n], 1L, 2L)
  )
}

#' Run the full GLS pipeline for a single deployment
#'
#' End-to-end: read the raw logger, detect and filter twilights, deduce in-situ
#' SST, and reconstruct a most-probable, SST-constrained track with the particle
#' model. This is the single-deployment engine behind
#' \code{\link{run_gls_pipeline_batch}}.
#'
#' @param path Directory (or light-file path) for one deployment; passed to
#'   \code{\link{read_gls}}.
#' @param config A \code{\link{probgls_config}} (biology + environment settings).
#'   If its \code{tagging.location} is \code{NULL} you must supply \code{colony}.
#' @param colony Optional \code{c(lon, lat)} to set/override the tagging location.
#' @param type Logger type for \code{\link{read_gls}} (\code{"auto"} by default).
#' @param light_threshold Light threshold (lux) for twilight detection.
#' @param temp_range Plausible SST range passed to \code{\link{deduce_sst}}.
#' @param run_model Logical; if \code{FALSE}, stop after preparing inputs
#'   (\code{trn}, \code{sensor}) without calling the particle model.
#' @param verbose Logical, print progress.
#'
#' @return A list of class \code{"gls_pipeline"} with \code{id}, \code{deployment},
#'   \code{twilights}, \code{trn}, \code{sensor}, and (if \code{run_model})
#'   \code{result} (a \code{\link{run_probgls}} output).
#'
#' @seealso \code{\link{run_gls_pipeline_batch}}, \code{\link{run_probgls}}
#' @examples
#' \dontrun{
#' cfg <- probgls_config(tagging_location = c(-115.174, 27.852),
#'                       boundary_box = c(-140, -80, 0, 55),
#'                       NOAA_OI_location = "results/oisst")
#' out <- run_gls_pipeline("birds/BW148", cfg)
#' head(out$result$track)
#' }
#' @export
run_gls_pipeline <- function(path,
                             config,
                             colony        = NULL,
                             type          = "auto",
                             light_threshold = 2,
                             temp_range    = c(-2, 32),
                             run_model     = TRUE,
                             verbose       = TRUE) {

  say <- function(...) if (isTRUE(verbose)) message(...)

  say("[read]      ", path)
  dep <- read_gls(path, type = type)

  if (!is.null(colony)) config[["tagging.location"]] <- colony
  if (is.null(config[["tagging.location"]]))
    stop("No tagging location: set `colony` or config$tagging.location.")

  say("[twilights] detecting (threshold = ", light_threshold, " lux)")
  twl_raw <- detect_twilights(dep$light, threshold = light_threshold)
  twl     <- filter_twilights(twl_raw, dep$light, threshold = light_threshold)
  trn     <- prepare_trn(twl)

  say("[sst]       deducing in-situ SST")
  sensor <- deduce_sst(dep, temp_range = temp_range)

  out <- list(id = dep$id, deployment = dep, twilights = twl,
              trn = trn, sensor = sensor, result = NULL)
  class(out) <- c("gls_pipeline", "list")

  if (!run_model) return(out)

  say("[model]     running probGLS (", config[["particle.number"]], " particles)")
  out$result <- run_probgls(trn, sensor, config, act = dep$wetdry)
  say("[done]      ", dep$id, ": ", nrow(out$result$track), " track steps")
  out
}

#' Batch-run the full GLS pipeline over a directory of deployments
#'
#' Auto-discovers deployments (sub-folders containing a light file), runs
#' \code{\link{run_gls_pipeline}} on each with robust per-deployment error
#' handling, writes per-deployment tracks, and returns a combined summary. This
#' is the movement-model counterpart to \code{\link{calibrate_gls_batch}}.
#'
#' @param root Root directory searched recursively for deployments.
#' @param config A \code{\link{probgls_config}}.
#' @param output_dir Where to write per-deployment track CSVs and the summary.
#' @param light_ext Light-file extensions that mark a deployment folder.
#' @param ... Passed to \code{\link{run_gls_pipeline}} (e.g. \code{colony},
#'   \code{light_threshold}).
#' @param verbose Logical, print progress.
#'
#' @return A list of class \code{"gls_pipeline_batch"} with:
#'   \item{summary}{one row per deployment (id, status, n steps, lat/lon medians)}
#'   \item{results}{named list of \code{gls_pipeline} outputs (successes)}
#'   \item{log}{per-deployment status / error messages}
#'
#' @examples
#' \dontrun{
#' cfg <- read_probgls_config("config.yml")
#' batch <- run_gls_pipeline_batch("birds", cfg, output_dir = "results/probGLS")
#' batch$summary
#' }
#' @export
run_gls_pipeline_batch <- function(root,
                                   config,
                                   output_dir = "probGLS_output",
                                   light_ext  = c("lux", "lig"),
                                   ...,
                                   verbose = TRUE) {

  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  validate_probgls_config(config, require_runtime = TRUE)

  # discover deployment folders (those directly containing a light file)
  all_light <- list.files(root, pattern = sprintf("\\.(%s)$", paste(light_ext, collapse = "|")),
                          recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
  deploy_dirs <- unique(dirname(all_light))
  if (!length(deploy_dirs)) stop("No light files (", paste(light_ext, collapse = "/"), ") under ", root)
  if (isTRUE(verbose)) message("Found ", length(deploy_dirs), " deployment(s).")

  results <- list(); log <- list(); rows <- list()
  for (d in deploy_dirs) {
    res <- tryCatch(
      run_gls_pipeline(d, config = config, verbose = verbose, ...),
      error = function(e) structure(list(error = conditionMessage(e)), class = "gls_error")
    )
    id <- basename(d)
    if (inherits(res, "gls_error")) {
      log[[id]] <- paste("FAILED:", res$error)
      rows[[id]] <- data.frame(id = id, status = "FAILED", n_steps = NA,
                               lat_median = NA, lon_median = NA)
      if (isTRUE(verbose)) message("  x ", id, ": ", res$error)
      next
    }
    id <- res$id
    results[[id]] <- res
    tr <- res$result$track
    utils::write.csv(tr, file.path(output_dir, paste0(id, "_probGLS_track.csv")),
                     row.names = FALSE)
    log[[id]] <- "SUCCESS"
    rows[[id]] <- data.frame(
      id = id, status = "SUCCESS", n_steps = nrow(tr),
      lat_median = stats::median(tr$lat, na.rm = TRUE),
      lon_median = stats::median(tr$lon, na.rm = TRUE))
  }

  summary <- do.call(rbind, rows); rownames(summary) <- NULL
  utils::write.csv(summary, file.path(output_dir, "pipeline_summary.csv"), row.names = FALSE)

  out <- list(summary = summary, results = results, log = log)
  class(out) <- c("gls_pipeline_batch", "list")
  out
}

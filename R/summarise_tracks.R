#' Summarise reconstructed tracks across a batch
#'
#' Produces a tidy, one-row-per-deployment summary from a
#' \code{\link{run_gls_pipeline_batch}} result (or a list of
#' \code{\link{run_probgls}} results): central location, latitudinal range and,
#' optionally, time spent beyond a latitude threshold. Taxon-agnostic — the
#' threshold is a plain argument, not a species assumption.
#'
#' @param x A \code{"gls_pipeline_batch"}, a named list of \code{"probgls_result"},
#'   or a named list of track data.frames.
#' @param lat_threshold Optional latitude; the summary reports the fraction of
#'   steps equatorward (\code{abs(lat) < threshold}) and poleward of it.
#'
#' @return data.frame with one row per deployment.
#' @examples
#' \dontrun{
#' summarise_tracks(batch, lat_threshold = 22)
#' }
#' @export
summarise_tracks <- function(x, lat_threshold = NULL) {
  tracks <- .as_track_list(x)
  rows <- lapply(names(tracks), function(id) {
    tr <- tracks[[id]]
    r <- data.frame(
      id         = id,
      n_steps    = nrow(tr),
      lon_median = stats::median(tr$lon, na.rm = TRUE),
      lat_median = stats::median(tr$lat, na.rm = TRUE),
      lat_min    = min(tr$lat, na.rm = TRUE),
      lat_max    = max(tr$lat, na.rm = TRUE)
    )
    if (!is.null(lat_threshold)) {
      r$frac_equatorward <- mean(abs(tr$lat) < lat_threshold, na.rm = TRUE)
    }
    r
  })
  do.call(rbind, rows)
}

#' Plot a reconstructed most-probable track
#'
#' Base-graphics map of one or more probGLS tracks over a coastline, in the
#' style of \code{\link{plot_track}}. Credible-interval columns, when present in
#' the tidy track, are not drawn here (kept intentionally simple).
#'
#' @param x A \code{"probgls_result"}, \code{"gls_pipeline"}, a track data.frame,
#'   or a named list of any of these.
#' @param colony Optional \code{c(lon, lat)} to mark the deployment location.
#' @param xlim,ylim Optional plot limits; default to the data extent (padded).
#' @param col Point/line colour (recycled over multiple tracks).
#' @param ... Passed to \code{\link[graphics]{plot}}.
#' @return Invisibly \code{NULL}; called for its side effect.
#' @examples
#' \dontrun{
#' plot_probgls_track(res, colony = c(-115.174, 27.852))
#' }
#' @export
#' @importFrom graphics points lines
#' @importFrom maps map
plot_probgls_track <- function(x, colony = NULL, xlim = NULL, ylim = NULL,
                               col = "#d1495b", ...) {
  tracks <- .as_track_list(x)
  alllon <- unlist(lapply(tracks, `[[`, "lon"))
  alllat <- unlist(lapply(tracks, `[[`, "lat"))
  if (is.null(xlim)) xlim <- range(alllon, na.rm = TRUE) + c(-2, 2)
  if (is.null(ylim)) ylim <- range(alllat, na.rm = TRUE) + c(-2, 2)

  graphics::plot(NA, xlim = xlim, ylim = ylim, xlab = "Longitude", ylab = "Latitude",
                 asp = 1, ...)
  maps::map("world", add = TRUE, fill = TRUE, col = "grey85", border = "grey60")
  cols <- grDevices::adjustcolor(rep(col, length.out = length(tracks)), 0.7)
  for (i in seq_along(tracks)) {
    tr <- tracks[[i]]
    graphics::lines(tr$lon, tr$lat, col = cols[i])
    graphics::points(tr$lon, tr$lat, col = cols[i], pch = 16, cex = 0.4)
  }
  if (!is.null(colony))
    graphics::points(colony[1], colony[2], pch = 24, bg = "gold", cex = 1.6)
  invisible(NULL)
}

# coerce the accepted input shapes to a named list of track data.frames
.as_track_list <- function(x) {
  if (inherits(x, "gls_pipeline_batch")) {
    return(lapply(x$results, function(r) r$result$track))
  }
  if (inherits(x, "probgls_result")) return(stats::setNames(list(x$track), "track"))
  if (inherits(x, "gls_pipeline"))   return(stats::setNames(list(x$result$track), x$id %||% "track"))
  if (is.data.frame(x))              return(stats::setNames(list(x), "track"))
  if (is.list(x)) {
    return(lapply(x, function(e) {
      if (inherits(e, "probgls_result")) e$track
      else if (inherits(e, "gls_pipeline")) e$result$track
      else if (is.data.frame(e)) e
      else stop("Unsupported element in list passed to track summary.")
    }))
  }
  stop("Cannot interpret `x` as track(s).")
}

#' Deduce in-situ sea-surface temperature from a logger's sensor channels
#'
#' The particle model matches the temperature the animal actually experienced
#' against satellite SST to constrain latitude. This function turns a logger's
#' temperature record into the \code{sensor} data frame that
#' \code{probGLS::prob_algorithm()} expects, flagging readings that should not
#' be trusted as SST (too few wet samples, physically implausible, or recorded
#' while the logger was dry).
#'
#' If the deployment already carries a Migrate \code{.sst} product
#' (\code{deployment$sst_raw}), that is used directly; otherwise SST is derived
#' from the temperature channel, optionally gated by the wet/dry channel.
#'
#' @param deployment A \code{"gls_deployment"} from \code{\link{read_gls}}, or a
#'   \code{data.frame} with columns \code{Date} and \code{Temp}.
#' @param temp_range Numeric length-2 plausible SST range (deg C); readings
#'   outside are flagged \code{SST.remove = TRUE}.
#' @param min_wet_samples Minimum wet samples (when using a \code{.sst} product).
#' @param smooth_window Odd integer; running-median window (in records) applied
#'   to suppress single-record spikes. \code{1} disables smoothing.
#'
#' @return A data.frame with columns \code{dtime}, \code{SST} and
#'   \code{SST.remove} (logical). Rows with \code{SST.remove = TRUE} are kept but
#'   marked, matching the probGLS convention \code{sensor[sensor$SST.remove == FALSE, ]}.
#'
#' @references Merkel B et al. (2016) A probabilistic algorithm to process
#'   geolocation data. \emph{Movement Ecology} 4:26.
#' @seealso \code{\link{read_gls}}, \code{\link{run_probgls}}
#' @examples
#' \dontrun{
#' dep <- read_gls("birds/BW148")
#' sen <- deduce_sst(dep, temp_range = c(-2, 32))
#' table(sen$SST.remove)
#' }
#' @export
deduce_sst <- function(deployment,
                       temp_range     = c(-2, 32),
                       min_wet_samples = 5,
                       smooth_window  = 3) {

  if (inherits(deployment, "gls_deployment")) {
    if (!is.null(deployment$sst_raw)) {
      s <- deployment$sst_raw
      df <- data.frame(dtime = s$Date, SST = s$SST,
                       n = if (!is.null(s$n_samples)) s$n_samples else NA_real_)
      df$SST.remove <- (!is.na(df$n) & df$n < min_wet_samples)
    } else if (!is.null(deployment$temperature) &&
               "Temp" %in% names(deployment$temperature)) {
      df <- .sst_from_temp(deployment$temperature, deployment$wetdry)
    } else {
      stop("Deployment has no usable temperature channel. Note that Migrate ",
           "Technology '.deg' files usually contain WET/DRY immersion, not ",
           "temperature - supply the '.sst' file for sea temperature.")
    }
  } else if (is.data.frame(deployment)) {
    df <- .sst_from_temp(deployment, NULL)
  } else {
    stop("`deployment` must be a gls_deployment or a data.frame(Date, Temp).")
  }

  df <- df[order(df$dtime), , drop = FALSE]

  # optional running-median de-spiking
  if (smooth_window > 1 && nrow(df) >= smooth_window) {
    df$SST <- .runmed_odd(df$SST, smooth_window)
  }

  # flag physically implausible values
  df$SST.remove <- df$SST.remove |
    is.na(df$SST) | df$SST < temp_range[1] | df$SST > temp_range[2]

  df[, c("dtime", "SST", "SST.remove")]
}

# derive SST from a temperature series, gated by wet/dry when available
.sst_from_temp <- function(temp_df, wetdry) {
  stopifnot(all(c("Date", "Temp") %in% names(temp_df)))
  df <- data.frame(dtime = temp_df$Date, SST = temp_df$Temp, SST.remove = FALSE)
  if (!is.null(wetdry) && all(c("Date", "wet") %in% names(wetdry))) {
    # nearest wet/dry state within 30 min; dry readings are not SST
    wd <- wetdry[order(wetdry$Date), ]
    idx <- findInterval(as.numeric(df$dtime), as.numeric(wd$Date))
    idx[idx < 1] <- 1
    near_wet <- wd$wet[pmax(idx, 1)]
    df$SST.remove <- df$SST.remove | (!is.na(near_wet) & near_wet <= 0)
  }
  df
}

# running median with an odd window (base stats::runmed), NA-safe
.runmed_odd <- function(x, k) {
  k <- as.integer(k); if (k %% 2 == 0) k <- k + 1L
  ok <- !is.na(x)
  if (sum(ok) < k) return(x)
  y <- x
  y[ok] <- stats::runmed(x[ok], k, endrule = "keep")
  y
}

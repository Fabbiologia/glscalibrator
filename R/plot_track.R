#' Plot Bird Track
#'
#' Creates a map showing the estimated movement track of a bird
#'
#' @param results data.frame with Latitude and Longitude columns
#' @param colony_lat Numeric latitude of colony
#' @param colony_lon Numeric longitude of colony
#' @param bird_id Character ID for plot title
#' @param output_dir Directory to save plot
#' @param hemisphere Character hemisphere check result
#'
#' @return NULL (creates PNG file)
#'
#' @export
#' @importFrom maps map
#' @importFrom grDevices dev.off png
#' @importFrom graphics abline legend lines par points title
plot_track <- function(results, colony_lat, colony_lon, bird_id,
                       output_dir, hemisphere = "") {

  lat_range <- range(results$Latitude)
  lon_range <- range(results$Longitude)
  lat_buffer <- diff(lat_range) * 0.25
  lon_buffer <- diff(lon_range) * 0.25

  xlim_smart <- c(max(-180, lon_range[1] - lon_buffer),
                  min(180, lon_range[2] + lon_buffer))
  ylim_smart <- c(max(-90, lat_range[1] - lat_buffer),
                  min(90, lat_range[2] + lat_buffer))

  png(file.path(output_dir, paste0(bird_id, "_track.png")),
      width = 1800, height = 1200, res = 120)

  par(mar = c(5, 5, 4, 8))

  maps::map("world", xlim = xlim_smart, ylim = ylim_smart,
            col = "gray90", fill = TRUE, border = "gray70")

  lines(results$Longitude, results$Latitude, col = "blue", lwd = 2)
  points(results$Longitude, results$Latitude,
         pch = 16, cex = 0.8, col = "darkblue")

  points(colony_lon, colony_lat, pch = 17, cex = 2.5, col = "red")

  abline(h = seq(-90, 90, by = 10), col = "gray80", lty = 3, lwd = 0.5)
  abline(v = seq(-180, 180, by = 10), col = "gray80", lty = 3, lwd = 0.5)

  title(main = paste("Track:", bird_id),
        xlab = "Longitude (\u00b0E)", ylab = "Latitude (\u00b0N)")

  legend("topright",
         legend = c("Track", "Colony", hemisphere,
                    paste0("n = ", nrow(results), " positions")),
         pch = c(NA, 17, NA, NA),
         lty = c(1, NA, NA, NA),
         col = c("blue", "red", "black", "black"),
         bg = "white")

  dev.off()
}

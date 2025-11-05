#' Plot Calibration Diagnostics
#'
#' Creates diagnostic plots showing light data and detected twilights during
#' the calibration period.
#'
#' @param light_data data.frame with Date and Light columns
#' @param twilights data.frame with Twilight and Rise columns
#' @param threshold Numeric light threshold
#' @param bird_id Character ID for plot title
#' @param output_dir Directory to save plot
#'
#' @return NULL (creates PNG file)
#'
#' @export
#' @importFrom grDevices dev.off png
#' @importFrom graphics abline legend par plot points
plot_calibration <- function(light_data, twilights, threshold, bird_id, output_dir) {

  png(file.path(output_dir, paste0(bird_id, "_calibration.png")),
      width = 1800, height = 1000, res = 120)

  par(mfrow = c(2, 1), mar = c(5, 5, 4, 2))

  # Light curve
  plot(light_data$Date, light_data$Light,
       type = "l", col = "gray60",
       xlab = "Time", ylab = "Light (lux)",
       main = paste("Calibration:", bird_id))
  abline(h = threshold, col = "red", lty = 2)

  points(twilights$Twilight[twilights$Rise],
         rep(threshold, sum(twilights$Rise)),
         pch = 24, col = "orange", bg = "yellow", cex = 1.5)
  points(twilights$Twilight[!twilights$Rise],
         rep(threshold, sum(!twilights$Rise)),
         pch = 25, col = "blue", bg = "lightblue", cex = 1.5)

  legend("topleft", legend = c("Sunrise", "Sunset", "Threshold"),
         pch = c(24, 25, NA), lty = c(NA, NA, 2),
         col = c("orange", "blue", "red"))

  # Twilight sequence
  plot(twilights$Twilight, seq_along(twilights$Twilight),
       xlab = "Detected Twilight Time", ylab = "Twilight Index",
       main = "Twilight Sequence",
       pch = 16, col = ifelse(twilights$Rise, "orange", "blue"))
  legend("topleft", legend = c("Sunrise", "Sunset"),
         pch = 16, col = c("orange", "blue"))

  dev.off()
}

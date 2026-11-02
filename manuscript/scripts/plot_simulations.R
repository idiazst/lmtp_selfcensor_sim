# Scientific figure from saved, independently verified simulation summaries.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 2L)
summary <- read.csv(args[1L])
sizes <- c(500, 1000, 4000, 10000)
colors <- c(sdr = "#0072B2", tmle = "#D55E00")
symbols <- c(sdr = 16, tmle = 15)
mechanisms <- c(binary_longitudinal = "Binary treatment",
                discrete_dose = "Numerical dose")

draw_figure <- function() {
  par(mfrow = c(3, 2), mar = c(3.7, 4.4, 2.0, 0.7),
      mgp = c(2.8, 0.7, 0), tcl = -0.25, cex = 0.85,
      family = "serif", las = 1, bty = "l")
  for (field in c("root_n_bias", "n_mse", "coverage")) {
    for (mechanism in names(mechanisms)) {
      rows <- summary[summary$mechanism == mechanism & summary$horizon == 2L, ]
      stopifnot(nrow(rows) == 8L, length(unique(rows$mechanism)) == 1L)
      scale <- if (field == "coverage") 100 else 1
      ylim <- range(rows[[field]] * scale)
      if (field == "root_n_bias") ylim <- range(c(ylim, 0)) + c(-0.07, 0.07)
      if (field == "n_mse") ylim <- ylim * c(0.85, 1.2)
      if (field == "coverage") ylim <- c(75, 100)
      ylab <- switch(field, root_n_bias = expression(sqrt(n) %*% Bias),
                     n_mse = expression(n %*% MSE~"(log scale)"),
                     coverage = "95% interval coverage (%)")
      plot(NA, xlim = c(440, 11500), ylim = ylim,
           log = if (field == "n_mse") "xy" else "x", axes = FALSE,
           xlab = if (field == "coverage") "Sample size" else "", ylab = ylab)
      ticks <- axTicks(2)
      abline(h = ticks, col = "grey90", lwd = 0.5)
      axis(2, at = ticks)
      axis(1, at = sizes, labels = c("500", "1,000", "4,000", "10,000"), cex.axis = 0.85)
      box(bty = "l")
      if (field == "root_n_bias") {
        title(mechanisms[[mechanism]], cex.main = 1.05)
        abline(h = 0, col = "grey45", lty = 2, lwd = 0.7)
      }
      if (field == "coverage") abline(h = 95, col = "grey45", lty = 2, lwd = 0.7)
      for (method in names(colors)) {
        current <- rows[rows$estimator == method, ]
        current <- current[match(sizes, current$n), ]
        values <- current[[field]] * scale
        if (field == "coverage") arrows(sizes, current$coverage_mc_lower * 100,
          sizes, current$coverage_mc_upper * 100, angle = 90, code = 3,
          length = 0.025, col = colors[[method]], lwd = 0.7)
        lines(sizes, values, type = "b", pch = symbols[[method]],
              col = colors[[method]], lwd = 1.1, cex = 0.7)
      }
      if (field == "root_n_bias" && mechanism == "binary_longitudinal")
        legend("topright", legend = c("SDR", "TMLE"), col = colors,
               pch = symbols, lty = 1, bty = "n", cex = 0.8)
    }
  }
}

pdf(paste0(args[2L], ".pdf"), width = 6.4, height = 7.1, family = "Times",
    title = "Longitudinal simulation: final outcome", useDingbats = FALSE)
draw_figure()
dev.off()
# Let Ghostscript process the PDF fonts when available.
if (nzchar(Sys.which("gs"))) {
  embedded <- paste0(args[2L], "-embedded.pdf")
  embedFonts(paste0(args[2L], ".pdf"), outfile = embedded)
  stopifnot(file.rename(embedded, paste0(args[2L], ".pdf")))
}
png(paste0(args[2L], ".png"), width = 1152, height = 1278, res = 180)
draw_figure()
dev.off()

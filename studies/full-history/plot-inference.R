args <- commandArgs(TRUE)
root <- if (length(args)) args[1] else "work/full-history"
library(ggplot2)
a <- read.csv(file.path(root, "inference-diagnostics.csv"))
rows <- read.csv(file.path(root, "estimates.csv"))
rows <- rows[is.finite(rows$estimate) & is.finite(rows$std.error), ]
groups <- split(rows, with(rows, interaction(mechanism, n, method, horizon, drop = TRUE)))
set.seed(7100317)
calibration_mc <- do.call(rbind, lapply(groups, function(x) {
  errors <- x$estimate - x$truth
  count <- nrow(x)
  draws <- if (count > 1) replicate(2000, {
    index <- sample.int(count, count, replace = TRUE)
    sqrt(mean(x$std.error[index]^2)) / sd(errors[index])
  }) else NA_real_
  limits <- if (sum(is.finite(draws)) > 1)
    quantile(draws[is.finite(draws)], c(.025, .975), names = FALSE) else c(NA_real_, NA_real_)
  data.frame(mechanism = x$mechanism[1], n = x$n[1], method = x$method[1],
    horizon = x$horizon[1], calibration_mc_low = limits[1], calibration_mc_high = limits[2],
    bootstrap_replicates = 2000L, bootstrap_seed = 7100317L)
}))
write.csv(calibration_mc, file.path(root, "se-calibration-mc.csv"), row.names = FALSE)
a <- merge(a, calibration_mc, by = c("mechanism", "n", "method", "horizon"), all.x = TRUE)
a$mechanism <- factor(a$mechanism, c("binary", "dose"),
                      c("Binary treatment", "Numerical dose"))
a$horizon <- factor(a$horizon, c(1, 2), c("Time 1", "Time 2"))
a$method <- factor(a$method, c("sdr", "tmle"), c("SDR", "TMLE"))
multiple_sizes <- length(unique(a$n)) > 1
manifest_path <- file.path(root, "specification.rds")
specification <- if (file.exists(manifest_path)) readRDS(manifest_path)$specification else "Saved specification"
returned <- if (length(unique(a$returned)) == 1) as.character(a$returned[1]) else
  paste(range(a$returned), collapse = " to ")
subtitle <- paste0(specification, "; ", if (multiple_sizes) "" else
  paste0("n = ", format(unique(a$n), big.mark = ",", trim = TRUE), "; "),
  returned, " returned replications per cell")
if (multiple_sizes) a$x <- a$n else a$x <- a$method
base <- ggplot(a, aes(x = x, color = method, shape = method, group = method)) +
  facet_grid(mechanism ~ horizon) +
  scale_color_manual(values = c(SDR = "#0072B2", TMLE = "#D55E00")) +
  scale_shape_manual(values = c(SDR = 16, TMLE = 17)) +
  theme_bw(base_size = 11) +
  theme(legend.position = if (multiple_sizes) "bottom" else "none",
        plot.caption = element_text(hjust = 0), panel.grid.minor = element_blank()) +
  labs(x = if (multiple_sizes) "Sample size" else NULL, color = NULL, shape = NULL,
       subtitle = subtitle)
if (multiple_sizes) base <- base + scale_x_log10(breaks = sort(unique(a$n)))
position <- if (multiple_sizes) position_dodge(width = .025) else position_identity()
coverage <- base + geom_hline(yintercept = .95, linetype = "dashed", color = "grey35") +
  geom_errorbar(aes(ymin = coverage_mc_low, ymax = coverage_mc_high),
                width = if (multiple_sizes) .025 else .12, position = position) +
  geom_point(aes(y = coverage), size = 2.6, position = position) +
  scale_y_continuous(labels = function(x) paste0(round(100 * x), "%")) +
  labs(title = "Confidence interval coverage", y = "Coverage of nominal 95% intervals",
       caption = "Error bars: pointwise 95% Wilson Monte Carlo intervals. No estimator intervals were changed.")
bias <- base + geom_hline(yintercept = 0, color = "grey35", linetype = "dashed") +
  geom_errorbar(aes(ymin = bias - qnorm(.975) * bias_mcse,
                    ymax = bias + qnorm(.975) * bias_mcse),
                width = if (multiple_sizes) .025 else .12, position = position) +
  geom_point(aes(y = bias), size = 2.6, position = position) +
  labs(title = "Estimated bias", y = "Mean estimate minus causal truth",
       caption = "Error bars: pointwise 95% Monte Carlo normal intervals for estimated bias.")
calibration <- base + geom_hline(yintercept = 1, color = "grey35", linetype = "dashed") +
  geom_errorbar(aes(ymin = calibration_mc_low, ymax = calibration_mc_high),
                width = if (multiple_sizes) .025 else .12, position = position) +
  geom_point(aes(y = rms_se_over_sd), size = 2.6, position = position) +
  labs(title = "Reported standard errors and observed variability",
       y = "RMS reported SE / empirical SD",
       caption = "Error bars: 95% Monte Carlo bootstrap intervals across simulation replications; no estimator refitting.")
for (name in c("coverage", "bias", "calibration")) {
  plot <- get(name)
  filename <- switch(name, coverage = "coverage-mc", bias = "bias-mc", calibration = "se-calibration")
  ggsave(file.path(root, paste0(filename, ".pdf")), plot, width = 8, height = 5.5)
  ggsave(file.path(root, paste0(filename, ".png")), plot, width = 8, height = 5.5, dpi = 180)
}

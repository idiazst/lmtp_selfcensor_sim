# Validate the R simulator separately from fitting. Invoke from the repo root.
source("studies/four-dose-pilot/common.R")
expected <- list(
  observed = list(natural = c(1/2, 2464793/4915200),
                  policy = c(55/96, 390931619/707788800)),
  full = list(natural = c(1/2, 2020193/4915200),
              policy = c(55/96, 379546979/707788800)))
baseline <- NULL
for (design in names(expected)) for (regime in names(expected[[design]])) {
  n <- 100000L
  data <- four_dose_data(n, 810219L, design, intervention = regime == "policy")
  stopifnot(all(data$R1 == 1), !anyNA(data[c("D1", "D2", "B1", "B2")]),
            all(data$D2 %in% 0:3), all(data$B2 %in% 0:1))
  if (regime == "natural") {
    first <- data[c("Y1","X1","D1","B1","Y2","X2","R2")]
    if (is.null(baseline)) baseline <- first else stopifnot(identical(baseline, first))
    miss <- data$R2 == 0
    if (design == "full") stopifnot(all(data$D2[miss] == 0), all(data$B2[miss] == 0))
    if (design == "observed") stopifnot(length(unique(4*data$B2[miss]+data$D2[miss])) == 8L)
  }
  for (t in 2:3) {
    y <- data[[paste0("Y", t)]]
    x <- data[[paste0("X", t)]]
    seen <- data[[paste0("R", t)]] == 1
    stopifnot(identical(!is.na(y), seen), identical(!is.na(x), seen),
              all(y[seen] > 0 & y[seen] < 1))
    # Use the generating visit probability for this independent simulator
    # test only. The estimation adapters never receive this probability.
    score <- ifelse(seen, y/(1/4+y/4+x/8), 0)
    difference <- (mean(score) - expected[[design]][[regime]][t-1])/(sd(score)/sqrt(n))
    stopifnot(abs(difference) < 5)
    cat(design, regime, t, sprintf("%.2f", difference), "Monte Carlo SEs from exact mean\n")
  }
}

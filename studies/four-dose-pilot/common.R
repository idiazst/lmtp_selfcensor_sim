# Four-dose pilot. Only the recorded columns of each generated dataset leave
# this function. The latent health pair still propagates after a missed visit.
four_dose_data <- function(n, seed, design, intervention = FALSE) {
  design <- match.arg(design, c("observed", "full"))
  set.seed(seed)
  y <- runif(n)
  x <- rbinom(n, 1, 1/4 + y/2)
  visit <- rep(1L, n)
  last_y <- y
  last_x <- x
  dat <- data.frame(Y1 = y, X1 = x, R1 = visit)
  for (t in 1:2) {
    zh <- if (design == "observed") (last_y + last_x)/2 else (y + x)/2
    dose_u <- runif(n)
    g0 <- (14 - 8*zh)/60
    g1 <- (22 - 4*zh)/60
    g2 <- (19 + 2*zh)/60
    dose <- (dose_u >= g0) + (dose_u >= g0 + g1) + (dose_u >= g0 + g1 + g2)
    aux <- as.integer(runif(n) < 1/4 + zh/2)
    if (design == "full") {
      dose[visit == 0] <- 0L
      aux[visit == 0] <- 0L
    }
    if (intervention) {
      dose[visit == 1] <- pmin(dose[visit == 1] + 1L, 3L)
      if (design == "full")
        dose[visit == 0] <- sample.int(4L, sum(visit == 0), replace = TRUE) - 1L
    }
    dat[[paste0("D", t)]] <- dose
    dat[[paste0("B", t)]] <- aux
    e <- 1/4 + (y + x)/4
    x <- as.integer(runif(n) < (e + aux)/2)
    component <- runif(n)
    # Use one uniform variate per beta draw, independently of the mixture label.
    shape1 <- ifelse(component < 1/2, dose + 1L,
                     ifelse(component < 1 - y/2, 1L, 3L))
    shape2 <- ifelse(component < 1/2, 4L - dose,
                     ifelse(component < 1 - y/2, 3L, 1L))
    y <- (x + 7*qbeta(runif(n), shape1, shape2))/8
    visit <- as.integer(runif(n) < 1/4 + y/4 + x/8)
    last_y[visit == 1] <- y[visit == 1]
    last_x[visit == 1] <- x[visit == 1]
    dat[[paste0("Y", t + 1L)]] <- ifelse(visit == 1, y, NA_real_)
    dat[[paste0("X", t + 1L)]] <- ifelse(visit == 1, x, NA_integer_)
    dat[[paste0("R", t + 1L)]] <- visit
  }
  dat
}

four_dose_folds <- function(data, seed, outer_folds = 4L) {
  set.seed(seed + 100L)
  lmtp:::make_folds(data, V = outer_folds, strata_ids = paste(data$R2, data$R3),
                    cluster_ids = seq_len(nrow(data)))
}

# Two low-dimensional ridge learners. All basis choices are made using X
# in the learner's training split, then applied unchanged to held-out people.
pilot_basis <- function(x, spec) {
  raw <- as.matrix(x[, spec$names, drop = FALSE])
  columns <- list(raw)
  for (j in spec$dose)
    columns <- c(columns, list(1 * (raw[, j] == 1), 1 * (raw[, j] == 2)))
  if (spec$smooth) {
    for (j in spec$continuous)
      columns <- c(columns, list(pmax(raw[, j] - 1/3, 0), pmax(raw[, j] - 2/3, 0)))
    if (length(spec$dose) && length(spec$continuous))
      columns <- c(columns, list(raw[, tail(spec$dose, 1)] * raw[, tail(spec$continuous, 1)]))
  }
  do.call(cbind, c(columns, list(rep(0, nrow(x)))))
}

pilot_regression <- function(Y, X, newX, family, obsWeights, smooth) {
  dose <- which(vapply(X, function(col) all(col %in% 0:3) && length(unique(col)) > 2L, TRUE))
  continuous <- which(vapply(X, function(col) any(col != floor(col)), TRUE))
  spec <- list(names = names(X), dose = dose, continuous = continuous, smooth = smooth)
  design <- pilot_basis(X, spec)
  use_fit <- length(unique(Y[obsWeights > 0])) > 1L &&
    any(vapply(seq_len(ncol(design)), function(j) length(unique(design[, j])) > 1L, TRUE))
  object <- list(spec = spec, mean = weighted.mean(Y, obsWeights), model = NULL)
  if (use_fit) {
    family_name <- if (family$family == "binomial") "binomial" else "gaussian"
    response <- if (family_name == "binomial") cbind(1-Y, Y) else Y
    object$model <- glmnet::glmnet(design, response, family = family_name,
      weights = obsWeights, alpha = 0, lambda = 0.02, standardize = TRUE)
    if (object$model$jerr != 0 || !length(object$model$lambda)) stop("Ridge fit did not converge.")
  }
  class(object) <- "four_dose_regression"
  list(pred = predict(object, newX), fit = object)
}

predict.four_dose_regression <- function(object, newdata, ...) {
  if (is.null(object$model)) return(rep(object$mean, nrow(newdata)))
  as.numeric(predict(object$model, pilot_basis(newdata, object$spec), type = "response"))
}

SL.pilot_linear <- function(Y, X, newX, family, obsWeights, ...)
  pilot_regression(Y, X, newX, family, obsWeights, FALSE)
SL.pilot_spline <- function(Y, X, newX, family, obsWeights, ...)
  pilot_regression(Y, X, newX, family, obsWeights, TRUE)

four_dose_specification <- function(crossfit = "outer") {
  profile <- match.arg(Sys.getenv("FOUR_DOSE_PROFILE", "baseline"),
    c("baseline", "support", "rich_adjoint", "support_rich"))
  library <- function(link) list(
    sieve_md = list(method = "sieve_md", control = list(link = link,
      target_basis = "poly", target_degree = 2L, instrument_basis = "poly",
      instrument_degree = 2L, penalty_on = "link",
      penalty_scales = 10^seq(-10, 0, by = 0.25))),
    landweber = list(method = "landweber", control = list(link = link,
      target_basis = "poly", target_degree = 2L, instrument_basis = "poly",
      instrument_degree = 2L, precondition = TRUE)),
    pmmr = list(method = "pmmr", control = list(link = link)))
  control <- lmtp::lmtp_control(.learners_outcome_folds = 3L, .learners_trt_folds = 3L,
    .trim = 1, .discrete = FALSE, .return_full_fits = TRUE, .isotonic_constraint = FALSE,
    .cm_kernel = "rbf", .cm_project_psd = TRUE)
  adjoint <- library("identity")
  if (profile %in% c("rich_adjoint", "support_rich")) {
    for (candidate in c("sieve_md", "landweber")) {
      adjoint[[candidate]]$control$target_basis <- "quadratic"
      adjoint[[candidate]]$control$instrument_basis <- "quadratic"
    }
  }
  list(crossfit = crossfit, profile = profile,
       policy_support = profile %in% c("support", "support_rich"),
       learners = c("SL.pilot_linear","SL.pilot_spline","SL.mean"),
       bridge = library("inverse_logit"), adjoint = adjoint, control = control)
}

# Known support of the two full-history policies, independent of the natural
# treatment law. Defined outside the adapter so callbacks have stable environments.
four_dose_support_d <- function(data, trt) data[[trt[1L]]] > 0
four_dose_support_t <- function(data, trt) data[[trt[2L]]] == 0

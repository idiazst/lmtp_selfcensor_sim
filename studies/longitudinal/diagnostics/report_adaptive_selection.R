source("studies/longitudinal/diagnostics/adaptive_setup.R")
out <- adaptive_output
paths <- list.files(file.path(out, "jobs"), "[.]rds$", full.names = TRUE)
design <- fread(file.path(out, "design.csv"))
fingerprint <- readLines(file.path(out,"fingerprint.txt"))[1L]
manifest <- jsonlite::fromJSON(file.path(out,"source-manifest.json"))
stopifnot(all(vapply(names(manifest),function(path)
  digest::digest(file=path,algo="sha256")==manifest[[path]],TRUE)))
stopifnot(length(paths) == nrow(design) || identical(Sys.getenv("ALLOW_PARTIAL"), "true"))
metrics <- weights <- points <- equations <- penalties <- projection_tuning <- failures <- checks <- runtimes <- list()
g <- make_mechanism("discrete_dose"); p <- enumerate_data(g)
population_task <- study_task(p, g)$task; population_truth <- true_values(p, g)
for (path in paths) {
  x <- readRDS(path); z <- x$design
  stopifnot(identical(x$fingerprint,fingerprint),x$package_version=="0.3.0.9025")
  set.seed(z$seed); d <- draw_data(4000L, g); task <- study_task(d, g)$task; nu <- true_values(d, g)
  stopifnot(x$data_sha256 == digest::digest(d, algo = "sha256"), !length(intersect(x$training, x$validation)))
  s <- z$time - 1L; H <- task$vars$history("A", s); A <- task$vars$A[[s]]
  B <- as.matrix(task$natural[, c(H, A), drop = FALSE])
  V <- as.matrix(cbind(task$natural[, H, drop = FALSE], d[, c(paste0("C", z$time, "_covariate"), paste0("Y", z$time))]))
  PB <- as.matrix(population_task$natural[, c(H, A), drop = FALSE])
  PV <- as.matrix(cbind(population_task$natural[, H, drop = FALSE], p[, c(paste0("C", z$time, "_covariate"), paste0("Y", z$time))]))
  measured <- d[[paste0("R", z$time)]] == 1L; pm <- p[[paste0("R", z$time)]] == 1L
  pp <- apply(population_truth$ratios[, seq_len(s), drop = FALSE], 1L, prod) *
    ifelse(pm, p[[paste0("Y", z$time)]], 0)
  meta <- function(q, selection = z$selection) cbind(data.table(selected = z$selected, seed = z$seed,
    n = 4000L, time = z$time, fold = z$fold, selection = selection), q)
  runtimes[[length(runtimes)+1L]] <- meta(data.table(seconds = x$seconds))
  baseline_path <- sprintf("results/longitudinal/ensemble-statistic-check/jobs/discrete_dose-seed%d-n4000-t%d-fold%d-u.rds", z$seed, z$time, z$fold)
  baseline <- readRDS(baseline_path)
  stopifnot(identical(baseline$training, x$training), identical(baseline$validation, x$validation))
  selections <- list(); selections[[z$selection]] <- x
  # The two adaptive records share the same baseline; include it once.
  if (z$selection == "robins") selections$rkhs_u <- baseline
  for (selection in names(selections)) for (type in c("bridge", "adjoint")) {
    model <- selections[[selection]][[type]]
    if (!is.null(model$error)) {
      failures[[length(failures)+1L]] <- meta(data.table(function_name = type, candidate = "ensemble",
        scope = "outer fit", message = model$error), selection)
      if (is.null(model$condition$candidates)) next
      checks[[length(checks)+1L]] <- meta(data.table(function_name = type,
        ensemble_status = "failed_discrepancy_constraint", ensemble_threshold = model$condition$threshold,
        ensemble_score = model$condition$minimum_loss, discrepancy_ok = FALSE),selection)
      model <- list(candidates = model$condition$candidates, candidate_failures = model$condition$candidate_failures,
        fold_penalty_cv = model$condition$fold_penalty_cv, weights = numeric(), ensemble_failed = TRUE)
    }
    if (length(model$candidate_failures)) for (failure in model$candidate_failures) {
      failures[[length(failures)+1L]] <- meta(data.table(function_name = type,
        candidate = failure$candidate, scope = failure$scope, message = failure$message), selection)
    }
    if (length(model$weights)) weights[[length(weights)+1L]] <- meta(data.table(function_name = type,
      candidate = names(model$weights), weight = as.numeric(model$weights)), selection)
    if (selection != "rkhs_u" && !isTRUE(model$ensemble_failed)) {
      G <- Reduce(`+`, Map(function(piece, count) (if(selection == "robins") piece$robins else piece$discrepancy) *
        count / sum(model$fold_n_scored), model$fold_scores, model$fold_n_scored))
      replay_error <- max(abs(G-model$gram))
      stopifnot(replay_error < 1e-12)
      for (plan in model$selection_audit) {
        stopifnot(!length(intersect(plan$train, plan$projection)),
          !length(intersect(plan$train, plan$validation)), !length(intersect(plan$projection, plan$validation)))
      }
      w <- model$weights[model$active_candidates]
      discrepancy_ok <- selection != "syrgkanis" || as.numeric(crossprod(w, G %*% w)) <= model$solver$threshold + 1e-10
      stopifnot(discrepancy_ok, !model$psd_projection$applied)
      checks[[length(checks)+1L]] <- meta(data.table(function_name = type, replay_error = replay_error,
        discrepancy_ok = discrepancy_ok, ensemble_status = model$solver$status,
        ensemble_threshold = model$solver$threshold, ensemble_score = model$cv_loss,
        candidates = length(model$candidates)), selection)
    }
    if (selection != "rkhs_u") {
      scopes <- c("final_refit", paste0("learner_fold_", seq_along(model$fold_penalty_cv)))
      for (candidate in names(model$candidates)) for (scope in scopes) {
        cv <- if (scope == "final_refit") model$candidates[[candidate]]$penalty_cv else
          model$fold_penalty_cv[[as.integer(sub("learner_fold_", "", scope))]][[candidate]]
        if (is.null(cv)) next
        cv <- as.data.table(cv); setnames(cv, "selected", "penalty_selected")
        penalties[[length(penalties)+1L]] <- meta(cbind(data.table(function_name=type,candidate=candidate,scope=scope),cv),selection)
      }
      for(candidate in names(model$candidates)) for(entry in model$candidates[[candidate]]$projection_cv) {
        for(projection in entry$projections) if(!is.null(projection))
          projection_tuning[[length(projection_tuning)+1L]] <- meta(cbind(data.table(function_name=type,
            candidate=candidate,penalty_scale=entry$scale),as.data.table(projection)),selection)
      }
    }
    X <- if(type=="bridge") V else B; PX <- if(type=="bridge") PV else PB
    vi <- if(type=="bridge") x$validation[measured[x$validation]] else x$validation
    pi <- if(type=="bridge") which(pm) else seq_len(nrow(p))
    true_sample <- if(type=="bridge") nu$beta[vi,s] else nu$lambda[vi,s]
    true_population <- if(type=="bridge") population_truth$beta[pi,s] else population_truth$lambda[pi,s]
    fits <- c(if(!isTRUE(model$ensemble_failed)) list(ensemble=model),model$candidates)
    for (candidate in names(fits)) {
      fit <- fits[[candidate]]
      vp <- predict(fit,X[vi,,drop=FALSE]); pe <- predict(fit,PX[pi,,drop=FALSE])
      stopifnot(all(is.finite(vp)),all(is.finite(pe)))
      if(type=="bridge") stopifnot(all(vp>=1),all(pe>=1))
      beta <- adjoint <- rep(NA_real_,nrow(p))
      if(type=="bridge") beta[pi]<-pe else adjoint[pi]<-pe
      eq <- moment_tables(p,population_task,s,beta,adjoint,pp,p$probability)[[type]]
      if(candidate=="ensemble") equations[[length(equations)+1L]] <- meta(cbind(data.table(function_name=type),eq),selection)
      for (previous in c(NA_integer_,0L,1L)) {
        keep <- if(is.na(previous)) rep(TRUE,length(pi)) else p[[paste0("R",s)]][pi]==previous
        if(!any(keep)) next
        probability <- p$probability[pi][keep]; probability <- probability/sum(probability)
        metrics[[length(metrics)+1L]] <- meta(data.table(function_name=type,candidate=candidate,previous_measured=previous,
          function_rmse=sqrt(sum(probability*(pe[keep]-true_population[keep])^2)),
          equation_rmse=sqrt(sum(eq$probability*eq$residual^2)/sum(eq$probability)),
          equation_max=max(abs(eq$residual))),selection)
      }
      points[[length(points)+1L]] <- meta(data.table(function_name=type,candidate=candidate,row=vi,
        truth=true_sample,estimate=vp,previous_measured=d[[paste0("R",s)]][vi]),selection)
    }
  }
}
bind <- function(q) if(length(q)) rbindlist(q,fill=TRUE) else data.table()
metrics<-bind(metrics); weights<-bind(weights); points<-bind(points); equations<-bind(equations)
penalties<-bind(penalties); projection_tuning<-bind(projection_tuning)
failures<-bind(failures); checks<-bind(checks); runtimes<-bind(runtimes)
for(name in c("metrics","weights","equations","penalties","projection_tuning","failures","checks","runtimes"))
  fwrite(get(name),file.path(out,paste0(name,".csv")))
con<-gzfile(file.path(out,"out-of-sample-predictions.csv.gz"),"wt"); write.csv(points,con,row.names=FALSE);close(con)
summary<-metrics[,.(function_rmse=sqrt(mean(function_rmse^2)),equation_rmse=sqrt(mean(equation_rmse^2)),
  equation_max=max(equation_max),completed_folds=.N),by=.(selected,seed,time,selection,function_name,candidate,previous_measured)]
fwrite(summary,file.path(out,"summary.csv"))
weight_summary<-weights[,.(weight=mean(weight),completed_folds=.N),by=.(selected,seed,time,selection,function_name,candidate)]
fwrite(weight_summary,file.path(out,"weight-summary.csv"))
if(nrow(penalties)) {
  stopifnot(all(penalties[penalty_selected==TRUE,scale]>0))
  selected_penalties<-penalties[penalty_selected==TRUE]
  stopifnot(all(selected_penalties[selection=="syrgkanis",loss]<=
    selected_penalties[selection=="syrgkanis",noise_threshold]+1e-12))
}
graphics_type<-if(Sys.info()[["sysname"]]=="Darwin") "quartz" else "cairo"
colors<-c("#999999","#2166AC")
draw_panel<-function(q,label,type,limits){
  if(!nrow(q)){plot.new();title(main=label);text(.5,.5,"Fit failed; see failure table");return()}
  q<-unique(q[,.(truth,estimate,previous_measured,fold)])
  plot(q$truth,q$estimate,xlim=limits,ylim=limits,asp=1,pch=16,cex=.5,
    col=adjustcolor(colors[q$previous_measured+1L],alpha.f=.45),
    xlab="True value (selected solution)",ylab=paste("Estimated",type),main=label)
  abline(0,1,col="#C23B23",lwd=1.6,lty=2)
}
for(selected_seed in unique(points$selected)) for(outcome_time in 2:3){
  q<-points[selected==selected_seed & time==outcome_time]
  png(file.path(out,sprintf("%s-t%d-ensemble-y-equals-x.png",selected_seed,outcome_time)),
    width=2100,height=1350,res=175,type=graphics_type)
  par(mfrow=c(2,3),mar=c(4.3,4.6,2.4,1),oma=c(2.5,0,3,0))
  for(type in c("bridge","adjoint")) {
    all<-q[function_name==type & candidate=="ensemble"]
    limits<-if(nrow(all)) range(c(all$truth,all$estimate),finite=TRUE) else c(0,1)
    pad<-max(.04,.04*diff(limits));limits<-limits+c(-pad,pad)
    for(approach in c("rkhs_u","robins","syrgkanis")) draw_panel(all[selection==approach],approach,type,limits)
  }
  mtext(sprintf("Numerical dose, n=4,000, %s seed, outcome t=%d",selected_seed,outcome_time),outer=TRUE,line=1,cex=1.05)
  mtext("Held-out predictions; red diagonal y=x. Blue: preceding visit observed; gray: missed.",outer=TRUE,side=1,line=.5,cex=.85)
  dev.off()
  for(approach in c("robins","syrgkanis")){
    png(file.path(out,sprintf("%s-t%d-%s-candidates-y-equals-x.png",selected_seed,outcome_time,approach)),
      width=2100,height=1350,res=175,type=graphics_type)
    par(mfrow=c(2,3),mar=c(4.3,4.6,2.4,1),oma=c(2.5,0,3,0))
    for(type in c("bridge","adjoint")){
      all<-q[function_name==type & selection==approach & candidate!="ensemble"]
      limits<-range(c(q[function_name==type,truth],all$estimate),finite=TRUE);pad<-max(.04,.04*diff(limits));limits<-limits+c(-pad,pad)
      for(learner in c("sieve_md","landweber","pmmr")) draw_panel(all[candidate==learner],learner,type,limits)
    }
    mtext(sprintf("%s: n=4,000, %s seed, outcome t=%d",approach,selected_seed,outcome_time),outer=TRUE,line=1,cex=1.05)
    mtext("All held-out points retained. References may be nonunique; consult the equation errors.",outer=TRUE,side=1,line=.5,cex=.85)
    dev.off()
  }
}
png(file.path(out,"adjoint-defining-equations-t3.png"),width=2100,height=1350,res=175,type=graphics_type)
par(mfrow=c(2,3),mar=c(4.3,4.6,2.4,1),oma=c(2,0,3,0))
for(seed_name in c("largest_bias","smallest_bias")) {
  all<-equations[selected==seed_name & time==3L & function_name=="adjoint"]
  limits<-range(c(all$true_conditional_mean,all$estimated_conditional_mean),finite=TRUE)
  pad<-max(.04,.04*diff(limits));limits<-limits+c(-pad,pad)
  for(approach in c("rkhs_u","robins","syrgkanis")) {
    q<-all[selection==approach]
    if(!nrow(q)){plot.new();title(main=paste(seed_name,approach));text(.5,.5,"No feasible ensemble mixture");next}
    plot(q$true_conditional_mean,q$estimated_conditional_mean,xlim=limits,ylim=limits,asp=1,pch=16,cex=.5,
      col=adjustcolor("#2166AC",alpha.f=.4),xlab="Conditional mean of loading",ylab="Conditional mean of estimated adjoint",
      main=paste(seed_name,approach));abline(0,1,col="#C23B23",lwd=1.6,lty=2)
  }
}
mtext("Adjoint defining equations: numerical dose, n=4,000, final outcome",outer=TRUE,line=1,cex=1.05)
dev.off()
md<-c("# Robins and Syrgkanis selection: numerical dose, n=4,000","",
  "Limited diagnostic of the two previously selected datasets, seeds 5203041 and 5203167. Both follow-ups and three saved outer folds are evaluated. This is not a 200-replication study and supplies no new SDR/TMLE estimates or confidence-interval coverage.","",
  "The frozen DGP, datasets, original outer/learner splits, bridge inverse-expit links, unrestricted adjoints and three candidate classes are retained. All three candidates now select their ridge or stopping iteration, so this changes previously fixed PMMR/Landweber controls as well as the criterion. The extra independent projection sample also reduces intermediate fitting sample sizes. The original RKHS U fits are included as a frozen baseline, not refitted.","",
  "Robins uses the debiased projected conditional-equation score on a separate validation sample. Syrgkanis calibrates the actual full-training fit with an empirical critic and a common multiplier-bootstrap noise envelope over the evaluated path. Its ensemble minimizes the second moment of the fitted mixture subject to held-out discrepancy. These are documented adaptations around our native objectives and penalties; the papers' full estimator guarantees are not claimed.","",
  "Projection ridge is selected by training-only leave-one-out CV on a positive extendable grid. No DGP truth enters either selector. As in the preceding isolated diagnostic, the adjoint loading uses exact treatment ratios; no sequential regressions are fitted. The true functions are used only for evaluation and satisfy the population equations. References can be nonunique.","",
  "## Final-outcome ensemble results","","| Seed | Selector | Function | RMSE to reference | Equation RMSE | Completed folds |","|---|---|---|---:|---:|---:|")
for(i in which(summary$time==3L & summary$candidate=="ensemble" & is.na(summary$previous_measured))){z<-summary[i];md<-c(md,
  sprintf("| %d | %s | %s | %.5f | %.5f | %d/3 |",z$seed,z$selection,z$function_name,z$function_rmse,z$equation_rmse,z$completed_folds))}
md<-c(md,"","## Ensemble weights","","| Seed | Selector | Function | Candidate | Mean weight | Completed folds |","|---|---|---|---|---:|---:|")
for(i in which(weight_summary$time==3L)){z<-weight_summary[i];md<-c(md,sprintf("| %d | %s | %s | %s | %.4f | %d/3 |",
  z$seed,z$selection,z$function_name,z$candidate,z$weight,z$completed_folds))}
for(seed_name in unique(points$selected))md<-c(md,"",sprintf("![%s, final outcome](%s-t3-ensemble-y-equals-x.png)",seed_name,seed_name))
md<-c(md,"","## Failures and verification","",sprintf("%d recorded outer/candidate failures. All failures remain in failures.csv and the saved checkpoints; failed fits are not reported as successful coverage results.",nrow(failures)),
  "","Successful fits have disjoint fitting/projection/scoring samples for Robins validation, unchanged outer exclusion, replayed selection Grams, positive selected penalties, and feasible discrepancy mixtures. See checks.csv, penalties.csv, metrics.csv, weight-summary.csv and compressed out-of-sample predictions. Individual candidate plots and both follow-ups accompany the report.","",
  "Package branch: robins-syrgkanis-selection. Simulation branch: robins-syrgkanis-n4000. Full study pins and results are unchanged.")
md<-c(md,"","## Interpretation","",
  "The Robins adapter is not a uniform improvement in these two datasets. Compare bridge error, adjoint equation error and the preceding-visit-observed subset in summary.csv. Its extra independent projection sample reduces intermediate fit sizes, so this is not an isolated change of loss with identical fitted candidates.","",
  "The discrepancy adapter admits very strong bridge penalties. PMMR receives all bridge ensemble weight at the final outcome and approaches beta=2: a ridge on its inverse-expit linear predictor sends that predictor toward zero, whose inverse-expit is two. This is a consequence of retaining the native link-scale penalty, not the function-scale Tikhonov penalty in the cited paper. The bootstrap threshold also reflects sparse empirical moment categories; it must not be treated as a proven complexity bound.","",
  "The discrepancy adjoint ensemble constraint is infeasible in the recorded failed folds. Those fits are not replaced by another selector and their thresholds are not inflated. The individually tuned candidate functions are still evaluated and plotted. The failed ensemble panels are deliberately blank and labeled.","",
  "These results do not establish that either published method fails: they evaluate the documented adaptations to our native learners. They also do not establish repaired SDR/TMLE coverage.","",
  "![Adjoint equations](adjoint-defining-equations-t3.png)","",
  "Individual final-outcome candidates: [Robins, largest error](largest_bias-t3-robins-candidates-y-equals-x.png), [Syrgkanis, largest error](largest_bias-t3-syrgkanis-candidates-y-equals-x.png), [Robins, smallest error](smallest_bias-t3-robins-candidates-y-equals-x.png), [Syrgkanis, smallest error](smallest_bias-t3-syrgkanis-candidates-y-equals-x.png).")
md<-c(md,"","Package source: [7a180142](https://github.com/idiazst/cmbridge/commit/7a180142bdb6f8a2d7b2c8892e535206a0e49727). [Package CI passed](https://github.com/idiazst/cmbridge/actions/runs/38192555221). Local unit checks passed 532 assertions; package check had no errors or warnings and the existing closure-binding NOTE.","",
  "Measured fitting interval: October 11, 2026, 21:35:25–21:42:32 EDT (7.12 minutes), using six independent local R processes. Earlier preflight/calibration attempts and OpenMP failures are retained locally under .runtime/adaptive-pilot-v1 and .runtime/adaptive-attempt-v2. They are not merged into these results.")
writeLines(md,file.path(out,"REPORT.md"))
jsonlite::write_json(list(path="studies/longitudinal/diagnostics/report_adaptive_selection.R",
  sha256=digest::digest(file="studies/longitudinal/diagnostics/report_adaptive_selection.R",algo="sha256")),
  file.path(out,"postprocessing-manifest.json"),pretty=TRUE,auto_unbox=TRUE)
print(summary[time==3L & candidate=="ensemble" & is.na(previous_measured)])

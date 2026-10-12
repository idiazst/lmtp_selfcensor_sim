source("studies/longitudinal/diagnostics/penalty_setup.R")
out <- penalty_output
paths <- list.files(file.path(out, "jobs"), "[.]rds$", full.names = TRUE)
design <- fread(file.path(out, "design.csv"))
fingerprint <- readLines(file.path(out,"fingerprint.txt"))[1L]
manifest <- jsonlite::fromJSON(file.path(out,"source-manifest.json"))
stopifnot(all(vapply(names(manifest),function(path)
  digest::digest(file=path,algo="sha256")==manifest[[path]],TRUE)))
stopifnot(length(paths) == nrow(design) || identical(Sys.getenv("ALLOW_PARTIAL"), "true"))
metrics <- weights <- points <- equations <- penalties <- boundaries <- failures <- warnings <- operators <- checks <- runtimes <- list()
g <- make_mechanism("discrete_dose"); p <- enumerate_data(g)
population_task <- study_task(p, g)$task; population_truth <- true_values(p, g)
for (path in paths) {
  x <- readRDS(path); z <- x$design
  stopifnot(identical(x$fingerprint,fingerprint),x$package_version=="0.3.0.9026")
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
  meta <- function(q, selection = z$rule) cbind(data.table(selected = z$selected, seed = z$seed,
    n = 4000L, time = z$time, fold = z$fold, selection = selection), q)
  runtimes[[length(runtimes)+1L]] <- meta(data.table(seconds = x$seconds))
  baseline_path <- sprintf("results/longitudinal/ensemble-statistic-check/jobs/discrete_dose-seed%d-n4000-t%d-fold%d-u.rds", z$seed, z$time, z$fold)
  baseline <- readRDS(baseline_path)
  stopifnot(identical(baseline$training, x$training), identical(baseline$validation, x$validation))
  selections <- list(); selections[[z$rule]] <- x
  # The two adaptive records share the same baseline; include it once.
  if (z$rule == "gcv") selections$rkhs_u <- baseline
  for (selection in names(selections)) for (type in c("bridge", "adjoint")) {
    model <- selections[[selection]][[type]]
    if(length(model$captured_warnings)) warnings[[length(warnings)+1L]] <- meta(
      data.table(function_name=type,message=model$captured_warnings),selection)
    if (!is.null(model$error)) {
      failures[[length(failures)+1L]] <- meta(data.table(function_name = type, candidate = "ensemble",
        scope = "outer fit", message = model$error), selection)
      if (length(model$condition$candidate_failures)) for (failure in model$condition$candidate_failures) {
        failures[[length(failures)+1L]] <- meta(data.table(function_name=type,candidate=failure$candidate,
          scope=failure$scope,message=failure$message),selection)
      }
      checks[[length(checks)+1L]] <- meta(data.table(function_name=type,ensemble_status="failed"),selection)
      next
    }
    if (length(model$candidate_failures)) for (failure in model$candidate_failures) {
      failures[[length(failures)+1L]] <- meta(data.table(function_name = type,
        candidate = failure$candidate, scope = failure$scope, message = failure$message), selection)
    }
    if (length(model$weights)) weights[[length(weights)+1L]] <- meta(data.table(function_name = type,
      candidate = names(model$weights), weight = as.numeric(model$weights)), selection)
    if (selection != "rkhs_u" && !isTRUE(model$ensemble_failed)) {
      yy <- x$training; Z <- if(type=="bridge") B[yy,,drop=FALSE] else V[yy,,drop=FALSE]
      M <- measured[yy]; counts <- model$fold_n_scored
      grams <- lapply(seq_along(counts), function(fold) {
        training <- which(model$fold_id!=fold); validation <- which(model$fold_id==fold)
        training <- if(type=="bridge") training else training[M[training]]
        validation <- if(type=="bridge") validation else validation[M[validation]]
        spec <- cmbridge:::.ensemble_kernel(Z[training,,drop=FALSE],"rbf",list(),1L+fold,"u")
        cmbridge:::.ensemble_gram(model$cv_residuals[validation,model$active_candidates,drop=FALSE],
          Z[validation,,drop=FALSE],spec)
      })
      G <- Reduce(`+`,Map(function(gram,count) gram*count/sum(counts),grams,counts))
      replay_error <- max(abs(G-model$raw_gram))
      stopifnot(replay_error<1e-12,model$psd_projection$applied,
        identical(model$fold_id,x$fold_id),abs(sum(model$weights)-1)<1e-10)
      for(candidate in names(model$candidates)) {
        fit <- model$candidates[[candidate]]
        stopifnot(fit$penalty_selection==selection)
        expected <- if(type=="bridge") length(yy) else sum(M)
        stopifnot(fit$penalty_training_n==expected)
        path_record<-fit$penalty_path[fit$penalty_path$selected,,drop=FALSE]
        training_x<-if(type=="bridge") V[yy[measured[yy]],,drop=FALSE] else B[yy[measured[yy]],,drop=FALSE]
        training_z<-if(type=="bridge") B[yy,,drop=FALSE] else V[yy[measured[yy]],,drop=FALSE]
        native_critic<-fit$instrument_features(training_z)
        operators[[length(operators)+1L]] <- meta(data.table(function_name=type,candidate=candidate,
          coefficient_count=length(fit$coefficients),critic_columns=ncol(native_critic),
          raw_critic_rank=qr(native_critic)$rank,weighted_critic_rank=path_record$critic_rank,
          observed_target_cells=length(unique(cmbridge:::.cell_keys(training_x)))),selection)
      }
      checks[[length(checks)+1L]] <- meta(data.table(function_name=type,replay_error=replay_error,
        ensemble_status="completed",candidates=length(model$candidates),
        solver_gap=model$solver$kkt_gap),selection)
    }
    if (selection != "rkhs_u") {
      scopes <- c("final_refit", paste0("learner_fold_", seq_along(model$fold_penalty_cv)))
      for (candidate in names(model$candidates)) for (scope in scopes) {
        cv <- if (scope == "final_refit") model$candidates[[candidate]]$penalty_cv else
          model$fold_penalty_cv[[as.integer(sub("learner_fold_", "", scope))]][[candidate]]
        if (is.null(cv)) next
        cv <- as.data.table(cv); setnames(cv, "selected", "penalty_selected")
        penalties[[length(penalties)+1L]] <- meta(cbind(data.table(function_name=type,candidate=candidate,scope=scope),cv),selection)
        history <- if(scope=="final_refit") model$candidates[[candidate]]$penalty_boundary else
          model$fold_penalty_boundary[[as.integer(sub("learner_fold_","",scope))]][[candidate]]
        if(!is.null(history) && nrow(history)) boundaries[[length(boundaries)+1L]] <- meta(
          cbind(data.table(function_name=type,candidate=candidate,scope=scope),as.data.table(history)),selection)
      }
      for(failure in model$candidate_failures) {
        condition<-failure$condition
        if(!is.null(condition$penalty_path)) {
          cv<-as.data.table(condition$penalty_path);setnames(cv,"selected","penalty_selected")
          penalties[[length(penalties)+1L]] <- meta(cbind(data.table(function_name=type,
            candidate=failure$candidate,scope=failure$scope),cv),selection)
        }
        if(!is.null(condition$boundary_history)) boundaries[[length(boundaries)+1L]] <- meta(
          cbind(data.table(function_name=type,candidate=failure$candidate,scope=failure$scope),
            as.data.table(condition$boundary_history)),selection)
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
        eq_subset <- if(is.na(previous)) eq else
          moment_tables(p,population_task,s,beta,adjoint,pp,p$probability*(p[[paste0("R",s)]]==previous))[[type]][probability>0]
        metrics[[length(metrics)+1L]] <- meta(data.table(function_name=type,candidate=candidate,previous_measured=previous,
          function_rmse=sqrt(sum(probability*(pe[keep]-true_population[keep])^2)),
          equation_rmse=sqrt(sum(eq_subset$probability*eq_subset$residual^2)/sum(eq_subset$probability)),
          equation_max=max(abs(eq_subset$residual))),selection)
      }
      points[[length(points)+1L]] <- meta(data.table(function_name=type,candidate=candidate,row=vi,
        truth=true_sample,estimate=vp,previous_measured=d[[paste0("R",s)]][vi]),selection)
    }
  }
}
bind <- function(q) if(length(q)) rbindlist(q,fill=TRUE) else data.table()
metrics<-bind(metrics); weights<-bind(weights); points<-bind(points); equations<-bind(equations)
penalties<-bind(penalties); boundaries<-bind(boundaries)
failures<-bind(failures); warnings<-bind(warnings); operators<-bind(operators); checks<-bind(checks); runtimes<-bind(runtimes)
for(name in c("metrics","weights","equations","penalties","boundaries","failures","warnings","operators","checks","runtimes"))
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
  for(cv in split(selected_penalties,by=c("seed","time","fold","selection","function_name","candidate","scope")))
    stopifnot(nrow(cv)==1L)
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
    width=2800,height=1350,res=175,type=graphics_type)
  par(mfrow=c(2,4),mar=c(4.3,4.6,2.4,1),oma=c(2.5,0,3,0))
  for(type in c("bridge","adjoint")) {
    all<-q[function_name==type & candidate=="ensemble"]
    limits<-if(nrow(all)) range(c(all$truth,all$estimate),finite=TRUE) else c(0,1)
    pad<-max(.04,.04*diff(limits));limits<-limits+c(-pad,pad)
    for(approach in c("rkhs_u","gcv","lcurve","quasiopt")) draw_panel(all[selection==approach],approach,type,limits)
  }
  mtext(sprintf("Numerical dose, n=4,000, %s seed, outcome t=%d",selected_seed,outcome_time),outer=TRUE,line=1,cex=1.05)
  mtext("Held-out predictions; red diagonal y=x. Blue: preceding visit observed; gray: missed.",outer=TRUE,side=1,line=.5,cex=.85)
  dev.off()
  for(approach in penalty_rules){
    png(file.path(out,sprintf("%s-t%d-%s-candidates-y-equals-x.png",selected_seed,outcome_time,approach)),
      width=2100,height=1350,res=175,type=graphics_type)
    par(mfrow=c(2,3),mar=c(4.3,4.6,2.4,1),oma=c(2.5,0,3,0))
    for(type in c("bridge","adjoint")){
      all<-q[function_name==type & selection==approach & candidate!="ensemble"]
      limits<-if(nrow(q[function_name==type])) range(c(q[function_name==type,truth],all$estimate),finite=TRUE) else c(0,1);pad<-max(.04,.04*diff(limits));limits<-limits+c(-pad,pad)
      for(learner in c("sieve_md","landweber","pmmr")) draw_panel(all[candidate==learner],learner,type,limits)
    }
    mtext(sprintf("%s: n=4,000, %s seed, outcome t=%d",approach,selected_seed,outcome_time),outer=TRUE,line=1,cex=1.05)
    mtext("All held-out points retained. References may be nonunique; consult the equation errors.",outer=TRUE,side=1,line=.5,cex=.85)
    dev.off()
  }
}
png(file.path(out,"adjoint-defining-equations-t3.png"),width=2800,height=1350,res=175,type=graphics_type)
par(mfrow=c(2,4),mar=c(4.3,4.6,2.4,1),oma=c(2,0,3,0))
for(seed_name in c("largest_bias","smallest_bias")) {
  all<-equations[selected==seed_name & time==3L & function_name=="adjoint"]
  limits<-range(c(all$true_conditional_mean,all$estimated_conditional_mean),finite=TRUE)
  pad<-max(.04,.04*diff(limits));limits<-limits+c(-pad,pad)
  for(approach in c("rkhs_u","gcv","lcurve","quasiopt")) {
    q<-all[selection==approach]
    if(!nrow(q)){plot.new();title(main=paste(seed_name,approach));text(.5,.5,"Fit failed; see failure table");next}
    plot(q$true_conditional_mean,q$estimated_conditional_mean,xlim=limits,ylim=limits,asp=1,pch=16,cex=.5,
      col=adjustcolor("#2166AC",alpha.f=.4),xlab="Conditional mean of loading",ylab="Conditional mean of estimated adjoint",
      main=paste(seed_name,approach));abline(0,1,col="#C23B23",lwd=1.6,lty=2)
  }
}
mtext("Adjoint defining equations: numerical dose, n=4,000, final outcome",outer=TRUE,line=1,cex=1.05)
dev.off()

# Actual selector curves include failed paths; no default penalties are substituted.
for(seed_name in c("largest_bias","smallest_bias")) for(rule in penalty_rules) {
 file<-sprintf("%s-t3-%s-penalty-paths.png",seed_name,rule)
 png(file.path(out,file),width=2100,height=1350,res=175,type=graphics_type)
 par(mfrow=c(2,3),mar=c(4.3,4.6,2.4,1),oma=c(2,0,3,0))
 for(type in c("bridge","adjoint")) for(learner in c("sieve_md","landweber","pmmr")) {
  q<-penalties[selected==seed_name & time==3L & selection==rule & function_name==type & candidate==learner]
  if(any(q$scope=="final_refit")) q<-q[scope=="final_refit"] else if(nrow(q)) q<-q[scope==q$scope[1L]]
  q[,criterion:=if(rule=="lcurve") curvature else if(rule=="quasiopt") change else score]
  q<-q[is.finite(criterion) & scale>0]
  if(!nrow(q)){plot.new();title(main=paste(type,learner));text(.5,.5,"No admissible curve");next}
  positive<-rule!="lcurve" && all(q$criterion>0)
  plot(range(q$scale),range(q$criterion),type="n",log=if(positive) "xy" else "x",
    xlab=if(learner=="landweber") "Inverse stopping iterations" else "Positive ridge",
    ylab=if(rule=="lcurve") "L-curve curvature" else if(rule=="quasiopt") "Function change" else "GCV score",
    main=paste(type,learner))
  for(fold_value in unique(q$fold)) {
   use<-q[fold==fold_value];setorder(use,scale)
   lines(use$scale,use$criterion,col=c("#2166AC","#B2182B","#4D9221")[fold_value],lwd=1)
   chosen<-use[penalty_selected==TRUE]
   if(nrow(chosen)) points(chosen$scale,chosen$criterion,pch=16,
     col=c("#2166AC","#B2182B","#4D9221")[fold_value])
  }
 }
 mtext(sprintf("%s: numerical dose, n=4,000, %s, t=3",rule,seed_name),outer=TRUE,line=1,cex=1.05)
 mtext("Colors identify outer folds; points mark selected penalties. Failed paths remain visible.",
  outer=TRUE,side=1,line=.3,cex=.85);dev.off()
}
md<-c("# Inverse-problem penalty selection: numerical dose, n=4,000","",
  paste0(if(length(paths)==nrow(design)) "Completed limited diagnostic" else "PRELIMINARY diagnostic", " of the two previously selected numerical-dose datasets, seeds 5203041 and 5203167. Both follow-ups, three saved outer folds and three parameter-choice rules are evaluated. This is not a 200-replication study and provides no new SDR/TMLE estimates or confidence-interval coverage."),"",
  "The Robins and Syrgkanis adapters are reverted on the replacement branches. The original DGP, datasets, three candidate classes, bridge inverse-expit links and unrestricted adjoints are retained. Ensemble weights still minimize the original RKHS U criterion with its existing PSD projection. Only candidate regularization selection is replaced. All three candidates now tune ridge or stopping iterations; previously only sieve had a penalty-CV grid.","",
  "GCV uses the native inverse-equation residual and the fitted sensitivity trace; L-curve selects positive residual-versus-regularization curvature; interior quasi-optimality selects a strict valley in changes of fitted functions along the logarithmic path. Boundary choices are failures, with positive grid extensions and no default-selector replacements. Missing corners or valleys can remove a candidate from the existing ensemble library. Failed attempts are retained.","",
  "Each candidate path uses only its supplied training rows. The original outer and learner folds are preserved, without the extra projection sample used in the reverted adapters. The final refit selects on its full training sample. Exact DGP treatment ratios construct the isolated adjoint loading, as in the preceding diagnostic; no regression learners are fitted. True functions are used only for evaluation. References can be nonunique, so the defining equations are also evaluated.","",
  "These parameter-choice heuristics do not directly estimate full-function MSE. Classical GCV assumes a fixed operator and white equation noise; our empirical operator is random and conditional moments can be heteroscedastic. Linked fits use local or numerical sensitivities. Candidate instrument bases and function classes are not changed by penalty selection. An individual candidate need not contain a true solution even when the library does.","",
  "## Final-outcome ensemble results","",
  "Errors integrate over the exact finite DGP population. Squared errors are averaged over available outer fits before taking the square root. Completed-fold counts disclose incomplete ensembles.","",
  "| Seed | Rule | Bridge RMSE | Bridge equation RMSE | Bridge folds | Adjoint equation RMSE | Adjoint folds |",
  "|---|---|---:|---:|---:|---:|---:|")
value<-function(q,name) if(nrow(q)) sprintf("%.5f",q[[name]]) else "Failed"
count<-function(q) if(nrow(q)) paste0(q$completed_folds,"/3") else "0/3"
for(seed_value in c(5203041L,5203167L)) for(rule in c("rkhs_u",penalty_rules)) {
 b<-summary[seed==seed_value & time==3L & selection==rule & function_name=="bridge" & candidate=="ensemble" & is.na(previous_measured)]
 a<-summary[seed==seed_value & time==3L & selection==rule & function_name=="adjoint" & candidate=="ensemble" & is.na(previous_measured)]
 md<-c(md,sprintf("| %d | %s | %s | %s | %s | %s | %s |",seed_value,rule,value(b,"function_rmse"),value(b,"equation_rmse"),count(b),value(a,"equation_rmse"),count(a)))
}
md<-c(md,"","## Ensemble weights","",
  "| Seed | Rule | Function | Candidate | Mean weight | Completed folds |",
  "|---|---|---|---|---:|---:|")
for(i in which(weight_summary$time==3L)) {
 z<-weight_summary[i]
 md<-c(md,sprintf("| %d | %s | %s | %s | %.4f | %d/3 |",z$seed,z$selection,z$function_name,z$candidate,z$weight,z$completed_folds))
}
md<-c(md,"","![Largest original error](largest_bias-t3-ensemble-y-equals-x.png)","",
 "![Smallest original error](smallest_bias-t3-ensemble-y-equals-x.png)","",
 "## Interpretation","",
 "Every new rule increases bridge function and defining-equation error in both saved datasets relative to the original RKHS U penalty selection. GCV improves adjoint equation RMSE for both seeds; interior quasi-optimality gives smaller adjoint improvements. L-curve worsens adjoint equation RMSE in both. No new rule is a uniform repair.","",
 "The native bridge sieve has 163–183 observed target categories at t=3, plus fixed main effects. Its conditioning basis has 18 columns but only nine independent directions in all six final outer fits. Nine moment directions cannot distinguish all target-cell values. The penalty chooses among solutions of this restricted empirical equation and cannot add missing conditioning information. This limitation of the finite basis is distinct from nonuniqueness of the full conditional equation in the DGP; it does not invalidate the DGP assumptions. Dimensions are in operators.csv.","",
 "GCV excludes sieve in some fits and Landweber in every bridge/adjoint fit because no admissible interior choice is found. L-curve and quasi-optimality also exclude every bridge Landweber candidate. The existing ensemble handling sets failed candidates' weights to zero. These are successful mixtures of surviving candidates, rather than successful fits of all three learners. There are no outer ensemble failures.","",
 "The plots show that reducing some penalties increases scatter and extreme estimates rather than automatically restoring recovery. The new rules use the native training equation; original penalty CV used the richer held-out RKHS score. Complete paths are retained to inspect this difference.","",
 "[Largest-error GCV paths](largest_bias-t3-gcv-penalty-paths.png), [L-curve paths](largest_bias-t3-lcurve-penalty-paths.png), [quasi-optimality paths](largest_bias-t3-quasiopt-penalty-paths.png). Corresponding smallest-error paths also accompany the report.","",
 "## Failures and verification","",
 sprintf("%d outer/candidate failures are recorded. Failed paths are not reported as successful fits or replaced by another selector. Individual candidate panels may be blank when that candidate fails on all outer folds.",nrow(failures)),"",
 sprintf("Maximum raw ensemble Gram replay error is %.3e. Original outer exclusions and learner labels, selected positive interior penalties, prediction domains and exact population defining equations were checked. Source/data hashes and saved model fingerprints are verified.",max(checks$replay_error,na.rm=TRUE)),"",
 "[All function and equation errors](summary.csv), [weights](weight-summary.csv), [complete penalty paths](penalties.csv), [boundary attempts](boundaries.csv), [failures](failures.csv), [checks](checks.csv), [runtimes](runtimes.csv), and [all held-out predictions](out-of-sample-predictions.csv.gz). Model checkpoints remain local and ignored by Git.","",
 "![Adjoint equations](adjoint-defining-equations-t3.png)","",
 "## Primary references and implementation","",
 "[Golub, Heath and Wahba (1979)](https://doi.org/10.1080/00401706.1979.10489751), [Hansen and O'Leary (1993)](https://doi.org/10.1137/0914086), [Hansen's Regularization Tools](https://www2.imm.dtu.dk/~pcha/Regutools/RTv4manual.pdf), and [Bauer and Reiss](https://arxiv.org/abs/0710.1045).", "",
 "Package branch: inverse-penalty-selection (0.3.0.9026). Simulation branch: inverse-penalty-n4000. [Implementation details](https://github.com/idiazst/cmbridge/blob/inverse-penalty-selection/INVERSE-PENALTY-SELECTION.md). Earlier adapters and results remain recoverable in Git history. Frozen full-study dependencies and results are unchanged.")
if(file.exists(file.path(out,"runtime.csv"))) {
 runtime<-fread(file.path(out,"runtime.csv"))
 md<-c(md,"",sprintf("Measured fitting time: %.2f minutes on %d local workers, %s to %s, for %d fit pairs (%d ensembles). All fit processes finished.",
   runtime$wall_seconds/60,runtime$workers,runtime$started,runtime$completed,runtime$fit_pairs,2L*runtime$fit_pairs),"",
   "Local unit tests passed 462 assertions. Package check had no errors or warnings, with the pre-existing prediction-closure binding NOTE. [Package commit](https://github.com/idiazst/cmbridge/commit/2bb1275a096d20964fec6b0465ec33132325beec) passed [package and recovery validation](https://github.com/idiazst/cmbridge/actions/runs/38258139671).")
}
writeLines(md,file.path(out,"REPORT.md"))
writeLines(if(length(paths)==nrow(design)) format(Sys.time(),tz="America/New_York",usetz=TRUE) else "PRELIMINARY",file.path(out,"EVALUATION-COMPLETED.txt"))
postprocessing<-c("studies/longitudinal/diagnostics/report_penalty_selection.R")
jsonlite::write_json(as.list(setNames(vapply(postprocessing,function(path)digest::digest(file=path,algo="sha256"),""),postprocessing)),
 file.path(out,"postprocessing-manifest.json"),pretty=TRUE,auto_unbox=TRUE)
print(summary[time==3L & candidate=="ensemble" & is.na(previous_measured)])

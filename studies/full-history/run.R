args<-commandArgs(TRUE)
mechanism<-if(length(args)) args[1] else Sys.getenv('FH_MECHANISM','binary')
n<-as.integer(if(length(args)>1) args[2] else Sys.getenv('FH_N','1000'))
first<-as.integer(Sys.getenv('FH_FIRST','1'));last<-as.integer(Sys.getenv('FH_LAST','10'))
output<-Sys.getenv('FH_OUTPUT','work/full-history')
mode<-Sys.getenv('FH_LIBRARY','ensemble')
source('studies/full-history/dgp.R')
library(lmtp)
future::plan(future::sequential)
if(requireNamespace('data.table',quietly=TRUE)) data.table::setDTthreads(1)
g<-fh_mechanism(mechanism);truth<-fh_truth(g)
dir.create(file.path(output,'jobs'),recursive=TRUE,showWarnings=FALSE)
write.csv(fh_validate(g),file.path(output,paste0('truth-',mechanism,'.csv')),row.names=FALSE)
write.csv(fh_gradient_check(g),file.path(output,paste0('gradient-',mechanism,'.csv')),row.names=FALSE)
control<-lmtp_control(.trim=1,.learners_outcome_folds=3,.learners_trt_folds=3,
 .discrete=FALSE,.cm_kernel='cell',.return_full_fits=TRUE,.isotonic_constraint=FALSE)
lib<-if(mode=='sieve-diagnostic') list(sieve_md=list(method='sieve_md',control=list(
 target_basis='cell',instrument_basis='cell',link='inverse_logit',lambda=.001))) else NULL
sl<-if(mode=='sieve-diagnostic') 'SL.saturated_l1' else c('SL.saturated_l1_cv','SL.mean')
sources<-c('studies/full-history/dgp.R','studies/full-history/run.R')
manifest<-list(commit=Sys.getenv('GITHUB_SHA'),run=Sys.getenv('GITHUB_RUN_ID'),
 lmtp=as.character(packageVersion('lmtp')),cmbridge=as.character(packageVersion('cmbridge')),
 sources=setNames(vapply(sources,function(p) digest::digest(file=p,algo='sha256'),''),sources),
 control=control,library=lib,sl=sl,randomizer='Uniform(0,1)',ratio_draws=5L,k=1L)
fingerprint<-digest::digest(manifest,algo='sha256')
saveRDS(manifest,file.path(output,'specification.rds'))
design<-expand.grid(replicate=first:last,method=c('sdr','tmle'),horizon=1:2,
 stringsAsFactors=FALSE)
design$mechanism<-mechanism;design$n<-n
design$seed<-6100000L+match(mechanism,c('binary','dose'))*100000L+n*10L+design$replicate
design$truth<-truth[design$horizon]
write.csv(design,file.path(output,sprintf('design-%s-n%d-r%d-%d.csv',mechanism,n,first,last)),row.names=FALSE)
for(rep in first:last) {
 seed<-6100000L+match(mechanism,c('binary','dose'))*100000L+n*10L+rep
 job<-sprintf('%s-n%d-r%04d',mechanism,n,rep)
 path<-file.path(output,'jobs',paste0(job,'.rds'))
 if(file.exists(path)) {
  old<-readRDS(path);stopifnot(identical(old$fingerprint,fingerprint));next
 }
 generated<-fh_generate(n,seed,g);data<-generated$observed
 set.seed(seed+1L)
 folds<-lmtp:::make_folds(data,V=3,strata_ids=paste(data$R2,data$R3),cluster_ids=seq_len(n))
 results<-list();details<-list();warnings<-character();errors<-list();nuisance_cache<-new.env(parent=emptyenv())
 for(method in c('sdr','tmle')) {
  started<-Sys.time();cat(format(started),job,method,'START\n');flush.console()
  set.seed(seed+2L)
  fit<-tryCatch(withCallingHandlers(do.call(lmtp_full_history,c(list(data=data),fh_arguments(g),
    list(estimator=method,folds=folds,learners_outcome=sl,learners_trt=sl,
    bridge_library=lib,control=control,nuisance_cache=nuisance_cache))),warning=function(w) {
      warnings<<-c(warnings,conditionMessage(w));invokeRestart('muffleWarning')
    }),error=function(e)e)
  elapsed<-as.numeric(difftime(Sys.time(),started,units='secs'))
  if(inherits(fit,'error')) {
   errors[[method]]<-fit
   results[[method]]<-data.frame(mechanism=mechanism,n=n,replicate=rep,seed=seed,
    method=method,horizon=1:2,truth=truth,estimate=NA_real_,std.error=NA_real_,
    conf.low=NA_real_,conf.high=NA_real_,seconds=elapsed,error=conditionMessage(fit))
  } else {
   a<-as.data.frame(tidy(fit));a$truth<-truth;a$method<-method;a$horizon<-a$time;a$time<-NULL
   a$mechanism<-mechanism;a$n<-n;a$replicate<-rep;a$seed<-seed;a$seconds<-elapsed;a$error<-''
   results[[method]]<-a
   details[[method]]<-list(points=fit$unprojected_estimates,sequential=fit$sequential_estimates,
     correction=colMeans(fit$bridge_correction),sequential_variance=apply(fit$sequential_score,2,var),
     bridge_variance=apply(fit$bridge_correction,2,var),
     cross_covariance=vapply(1:2,function(h) cov(fit$sequential_score[,h],fit$bridge_correction[,h]),0),
     gradient_means=colMeans(fit$influence_functions),
     maximum_weight=apply(fit$propagation_weights,2,max),
     targeting=fit$targeting,folds=fit$folds,
     beta=lapply(fit$bridge_fits,function(f) f$beta_validation),
     adjoint_weights=lapply(fit$bridge_fits,function(f) lapply(f$adjoints,function(h) lapply(h,function(m) m$weights))))
  }
  cat(format(Sys.time()),job,method,'SAVED',elapsed,'seconds\n');flush.console()
  checkpoint<-list(fingerprint=fingerprint,manifest=manifest,results=results,details=details,errors=errors,warnings=unique(warnings),
    n=n,seed=seed,replicate=rep,mechanism=mechanism,session=capture.output(sessionInfo()))
  saveRDS(checkpoint,paste0(path,'.tmp'));stopifnot(file.rename(paste0(path,'.tmp'),path))
 }
}

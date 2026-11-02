# Exercise a third MNAR transition, including return after an earlier missed
# visit and the nonterminal adjoint loading that uses a depth-one regression.
source('studies/full-history/dgp.R')
library(lmtp)
g<-fh_mechanism('binary');n<-as.integer(Sys.getenv('FH_STRESS_N','4000'));seed<-7100001L
set.seed(seed);x<-data.frame(C1=rbinom(n,1,.5),R1=1)
for(s in 1:3) {
 c<-x[[paste0('C',s)]];r<-x[[paste0('R',s)]]
 x[[paste0('A',s)]]<-r*rbinom(n,1,.25+.5*c)
 nextc<-rbinom(n,1,fh_c(c,x[[paste0('A',s)]],g))
 x[[paste0('C',s+1)]]<-nextc
 x[[paste0('R',s+1)]]<-rbinom(n,1,fh_r(c,nextc))
}
complete<-x
for(s in 2:4) x[[paste0('C',s)]][x[[paste0('R',s)]]==0]<-NA_real_
truth<-numeric(3);previous<-.5;truth[1]<-.725
for(h in 2:3) {
 current<-truth[h-1];visit<-.55+.25*current-.1*previous
 truth[h]<-.1+.25*current+.5*(.35+.65*visit);previous<-current
}
set.seed(seed+1L);folds<-lmtp:::make_folds(x,V=3,strata_ids=paste(x$R2,x$R3,x$R4))
lib<-list(sieve_md=list(method='sieve_md',control=list(target_basis='cell',
 instrument_basis='cell',link='inverse_logit',lambda=.001)))
control<-lmtp_control(.trim=1,.learners_outcome_folds=3,.learners_trt_folds=3,.discrete=FALSE)
cache<-new.env(parent=emptyenv());fits<-list();results<-list()
alpha<-function(data,trt) rep(0,nrow(data));visit<-function(data,trt) rep(1,nrow(data))
continuation<-function(data,trt,epsilon) as.numeric(epsilon<.35)
for(method in c('sdr','tmle')) {
 set.seed(seed+2L);started<-Sys.time()
 fit<-lmtp_full_history(x,paste0('A',1:3),paste0('C',2:4),paste0('R',1:4),
  as.list(paste0('C',1:4)),alpha,visit,continuation,k=1,mtp=FALSE,folds=folds,
  estimator=method,learners_outcome='SL.saturated_l1',learners_trt='SL.saturated_l1',
  bridge_library=lib,control=control,nuisance_cache=cache)
 z<-as.data.frame(tidy(fit));z$truth<-truth;z$method<-method
 z$seconds<-as.numeric(difftime(Sys.time(),started,units='secs'));results[[method]]<-z
 fits[[method]]<-fit
 stopifnot(all(is.finite(fit$influence_functions)))
 if(method=='tmle') for(fold in fit$targeting) for(h in fold) stopifnot(max(abs(h$score))<1e-7)
}
out<-Sys.getenv('FH_STRESS_OUTPUT','work/full-history-stress');dir.create(out,recursive=TRUE,showWarnings=FALSE)
write.csv(do.call(rbind,results),file.path(out,'results.csv'),row.names=FALSE)
saveRDS(list(fits=fits,truth=truth,seed=seed,n=n,complete=complete,observed=x,
 commit=Sys.getenv('GITHUB_SHA'),run=Sys.getenv('GITHUB_RUN_ID'),session=capture.output(sessionInfo())),file.path(out,'stress.rds'))
print(do.call(rbind,results))

source("scripts/setup.R")
library(data.table)
outdir <- Sys.getenv("SIM_OUTPUT", "results/longitudinal")
Sys.setenv(SIM_OUTPUT = outdir, STUDY_SOURCE = "studies/longitudinal")
source("scripts/verify_results.R")
for (script in c("summarize.R", "write_reduced_report.R"))
  source(file.path("studies/longitudinal", script), local = new.env(parent = globalenv()))
# Correct the report's population-error table to retain outcome time. Fitting
# sources stay frozen; these are postprocessing changes only.
diagnostics<-fread(file.path(outdir,'population_diagnostics.csv'))
if(nrow(diagnostics)) {
  components<-c('population_bias','sequential_remainder','bridge_remainder')
  per_dataset<-diagnostics[,lapply(.SD,function(z)sum(z*fold_weight)),
    by=.(mechanism,n,replicate,seed,horizon,estimator,scenario),.SDcols=components]
  population_means<-per_dataset[,c(list(successful=.N),lapply(.SD,mean)),
    by=.(mechanism,n,horizon,estimator,scenario),.SDcols=components]
  fwrite(population_means,file.path(outdir,'population-error-by-outcome-time.csv'))
  report<-file.path(outdir,'REPORT.md')
  previous<-paste(readLines(report),collapse='\n')
  marker<-'## Conditional equations and estimation error'
  stopifnot(length(strsplit(previous,marker,fixed=TRUE)[[1L]])==2L)
  prefix<-strsplit(previous,marker,fixed=TRUE)[[1L]][1L]
  rows<-vapply(seq_len(nrow(population_means)),function(i) {
    z<-population_means[i]
    sprintf('| %s | %d | %d | %s | %d | %.6f | %.6f | %.6f |',
      if(z$mechanism=='binary_longitudinal')'Binary treatment'else'Numerical dose',
      z$n,z$horizon+1L,toupper(z$estimator),z$successful,z$population_bias,
      z$sequential_remainder,z$bridge_remainder)
  },'')
  writeLines(c(prefix,marker,'',
    'Evaluate each saved fitted contribution over the complete discrete population, then average the outer training samples using their validation sample sizes. The two contributions add to the fixed-function population error. Outcome times are reported separately.',
    '',
    'For SDR this evaluates the expectation of contributions from the fitted nuisance functions. TMLE targeting uses validation outcomes, so holding its final targeted functions fixed is a diagnostic calculation, not a conditional expectation given training data alone.',
    '',
    '| Treatment | n | Outcome time | Estimator | Successful | Population error | Sequential contribution | Bridge/adjoint contribution |',
    '| --- | --- | --- | --- | --- | --- | --- | --- |',rows,'',
    'The full-support saturated adjoint class contains a valid solution. The implemented sieve dictionary uses measured training combinations and mean continuation for unseen values; its realized finite-sample class need not contain a population solution. The fixed main-effect bridge classes contain a valid solution on the full support. The present study retains the full-population diagnostics for every saved successful fit; other versions and platforms are excluded.',
    '',
    '[Population values by outcome time](population-error-by-outcome-time.csv) retain the numerical calculations.'),report)
}
# Preserve the original conditional coverage and additionally count fit failures
# as producing no interval. Pending datasets are not completed observations.
summary<-fread(file.path(outdir,'summary.csv'))
estimates<-fread(file.path(outdir,'replicates.csv'))
keys<-c('mechanism','n','horizon','estimator','scenario')
covered<-estimates[,.(intervals_covering=sum(lower<=truth & upper>=truth)),by=keys]
availability<-merge(summary,covered,by=keys,all.x=TRUE)
availability[is.na(intervals_covering),intervals_covering:=0L]
availability[,coverage_including_failures:=ifelse(datasets_completed>0L,
  intervals_covering/datasets_completed,NA_real_)]
availability[,failure_fraction:=ifelse(datasets_completed>0L,failed/datasets_completed,NA_real_)]
availability[,`:=`(coverage_including_failures_mc_lower={
    z<-qnorm(.975);p<-coverage_including_failures;k<-datasets_completed
    (p+z^2/(2*k)-z*sqrt(p*(1-p)/k+z^2/(4*k^2)))/(1+z^2/k)},
  coverage_including_failures_mc_upper={
    z<-qnorm(.975);p<-coverage_including_failures;k<-datasets_completed
    (p+z^2/(2*k)+z*sqrt(p*(1-p)/k+z^2/(4*k^2)))/(1+z^2/k)})]
fwrite(availability,file.path(outdir,'coverage-including-failures.csv'))
plotdata<-availability[datasets_completed>0L]
plotdata[,outcome_time:=paste('Outcome at time',horizon+1L)]
plotdata[,mechanism_label:=c(binary_longitudinal='Binary treatment',discrete_dose='Numerical dose')[mechanism]]
p<-ggplot2::ggplot(plotdata,ggplot2::aes(x=n,y=coverage_including_failures,
  colour=toupper(estimator),group=estimator))+
  ggplot2::geom_hline(yintercept=.95,linetype='dashed',colour='grey40')+
  ggplot2::geom_errorbar(ggplot2::aes(ymin=coverage_including_failures_mc_lower,
    ymax=coverage_including_failures_mc_upper),width=70,position=ggplot2::position_dodge(width=140))+
  ggplot2::geom_point(position=ggplot2::position_dodge(width=140),size=2)+
  ggplot2::facet_grid(outcome_time~mechanism_label)+
  ggplot2::scale_x_continuous(breaks=c(500,1000,4000))+
  ggplot2::coord_cartesian(ylim=c(0,1))+
  ggplot2::labs(x='Sample size',y='Fraction with an interval containing the truth',colour='Estimator',
    caption='A failed fit produces no interval. Bars show 95% Monte Carlo intervals; pending datasets are excluded.')+
  ggplot2::theme_bw(base_size=12)
for(ext in c('png','pdf'))ggplot2::ggsave(file.path(outdir,'figures',paste0('coverage-including-failures.',ext)),
  p,width=10,height=7,dpi=180)
report<-file.path(outdir,'REPORT.md')
cat('\n## Coverage including failed fits\n\nThe preceding coverage estimates describe successful fits. ',
  'The additional [table](coverage-including-failures.csv) counts a failed fit as producing no interval ',
  'and uses all completed datasets as the denominator. Pending datasets are excluded. ',
  'Its Monte Carlo intervals describe simulation uncertainty.\n\n',
  '![Coverage including failed fits](figures/coverage-including-failures.png)\n',file=report,append=TRUE,sep='')
cat(length(paths),'of 1200 checkpoints summarized.\n')

status <- system2("python3", c("scripts/compress_tables.py", shQuote(outdir)))
stopifnot(status == 0L)

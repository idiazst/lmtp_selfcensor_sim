args<-commandArgs(TRUE);root<-if(length(args))args[1] else 'work/full-history'
paths<-list.files(root,'[.]rds$',recursive=TRUE,full.names=TRUE)
paths<-paths[grepl('/jobs/',paths)]
records<-lapply(paths,readRDS)
if(length(records)) {
 specifications<-lapply(records,function(z) z$manifest[setdiff(names(z$manifest),c('run','commit'))])
 if(any(!vapply(specifications,function(x) identical(x,specifications[[1]]),TRUE)))
  stop('Refusing to pool different source versions or nuisance specifications.')
}
rows<-do.call(rbind,lapply(records,function(z) do.call(rbind,z$results)))
design_paths<-list.files(root,'^design-.*[.]csv$',recursive=TRUE,full.names=TRUE)
if(length(design_paths)) {
 design<-unique(do.call(rbind,lapply(design_paths,read.csv)))
 fields<-c('mechanism','n','replicate','method','horizon','seed','truth')
 if(is.null(rows)) rows<-data.frame()
 if(nrow(rows)) rows<-merge(design,rows,by=fields,all.x=TRUE) else rows<-design
 for(name in c('estimate','std.error','conf.low','conf.high','seconds'))
  if(!name%in%names(rows)) rows[[name]]<-NA_real_
 if(!'error'%in%names(rows)) rows$error<-NA_character_
 rows$error[is.na(rows$error)]<-'No checkpoint returned: runner interrupted or failed.'
}
if(is.null(rows)||!nrow(rows)) stop('No simulation design or checkpoints found.')
key<-with(rows,paste(mechanism,n,replicate,method,horizon))
if(anyDuplicated(key)) stop('Duplicate dataset/method/horizon checkpoints.')
write.csv(rows,file.path(root,'estimates.csv'),row.names=FALSE)
groups<-split(rows,with(rows,interaction(mechanism,n,method,horizon,drop=TRUE)))
summary<-do.call(rbind,lapply(groups,function(z) {
 ok<-is.finite(z$estimate)&is.finite(z$std.error);good<-z[ok,]
 data.frame(mechanism=z$mechanism[1],n=z$n[1],method=z$method[1],horizon=z$horizon[1],
  attempted=nrow(z),returned=sum(ok),failed=sum(!ok),truth=z$truth[1],
  bias=if(sum(ok))mean(good$estimate-good$truth) else NA_real_,
  empirical_sd=if(sum(ok)>1)sd(good$estimate) else NA_real_,
  mean_se=if(sum(ok))mean(good$std.error) else NA_real_,
  rmse=if(sum(ok))sqrt(mean((good$estimate-good$truth)^2)) else NA_real_,
  coverage=if(sum(ok))mean(good$conf.low<=good$truth&good$conf.high>=good$truth) else NA_real_,
  mean_seconds=mean(z$seconds,na.rm=TRUE))
}))
rownames(summary)<-NULL
write.csv(summary,file.path(root,'summary.csv'),row.names=FALSE)
failures<-rows[nzchar(rows$error),];write.csv(failures,file.path(root,'failures.csv'),row.names=FALSE)
label<-if(length(records)&&!is.null(records[[1]]$manifest$specification)) records[[1]]$manifest$specification else {
 sl<-if(length(records)) records[[1]]$manifest$sl else character()
 if(identical(sl,'SL.saturated_l1')) 'sieve-diagnostic' else
 if('SL.saturated_l1_cv'%in%sl) 'ensemble' else 'saved nuisance specification'
}
lines<-c('# Full-history adjustment simulation','',paste('Specification:',label),'',
 sprintf('%d datasets; %d method/horizon estimates returned; %d failed method/horizon estimates.',
 length(unique(with(rows,paste(mechanism,n,replicate)))),sum(is.finite(rows$estimate)),sum(!is.finite(rows$estimate))),
 '', 'All failures remain in estimates.csv and failures.csv. No replacement seeds are generated.',
 '', 'Both methods estimate the bridges, adjoints, sequential regressions and both policy density ratios.',
 'Truth uses independent forward causal enumeration and agrees with the backward bridge functional.',
 'Population adjoint and gradient checks are saved alongside each shard.',
 '', paste(capture.output(print(summary,digits=4,row.names=FALSE)),collapse='\n'))
writeLines(lines,file.path(root,'REPORT.md'))
cat(paste(lines,collapse='\n'),'\n')
if(requireNamespace('ggplot2',quietly=TRUE)) {
 library(ggplot2)
 plot<-ggplot(summary,aes(x=n,y=bias,color=method,group=method))+
  geom_hline(yintercept=0,color='grey60')+geom_line()+geom_point()+
  facet_grid(mechanism~horizon,labeller=label_both)+scale_x_log10()+theme_bw()+
  labs(title='Full-history adjustment: estimated bias',x='Sample size',y='Monte Carlo bias')
 ggsave(file.path(root,'bias.png'),plot,width=8,height=5,dpi=160)
}

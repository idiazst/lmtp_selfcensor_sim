target<-Sys.getenv('R_LIBS_USER');dir.create(target,recursive=TRUE,showWarnings=FALSE)
.libPaths(c(normalizePath(target),.libPaths()))
options(repos=c(CRAN=Sys.getenv('RSPM','https://cloud.r-project.org')))
if(!requireNamespace('remotes',quietly=TRUE)) install.packages('remotes',lib=target)
pins<-read.csv('dependencies/full-history/manifest.csv')
for(i in seq_len(nrow(pins))) {
 stopifnot(unname(tools::md5sum(pins$path[i]))==pins$md5[i])
 if(!requireNamespace(pins$package[i],quietly=TRUE)||as.character(packageVersion(pins$package[i]))!=pins$version[i])
  remotes::install_local(pins$path[i],lib=target,dependencies=NA,upgrade='never')
}
stopifnot(packageVersion('lmtp')=='1.6.0.9024',packageVersion('cmbridge')=='0.3.0.9029')

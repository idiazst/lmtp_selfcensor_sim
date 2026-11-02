# Full-history DGP: visits depend on current latent health; treatment at visits
# depends on that health, including when earlier health was unrecorded.
fh_mechanism <- function(type = c("binary", "dose")) {
  type <- match.arg(type)
  list(type = type, levels = if (type == "binary") 0:1 else 0:3,
       continuation = if (type == "binary") c(.65, .35) else rep(.25, 4))
}
fh_g <- function(c, g) {
  if (g$type == "binary") return(c(1-(.25+.5*c), .25+.5*c))
  p <- exp(g$levels * .35 * (2*c-1)); p/sum(p)
}
fh_c <- function(c, a, g) .1 + .25*c + .5*a/max(g$levels)
fh_r <- function(previous, current) .55 + .25*current - .1*previous
fh_d <- function(a, g) if (g$type == "binary") rep(1, length(a)) else pmin(a+1, 3)
fh_generate <- function(n, seed, g) {
  set.seed(seed)
  d <- data.frame(C1 = rbinom(n,1,.5), R1 = 1)
  sample_a <- function(c) vapply(c, function(x) sample(g$levels,1,prob=fh_g(x,g)), 0L)
  d$A1 <- sample_a(d$C1)
  d$C2 <- rbinom(n,1,fh_c(d$C1,d$A1,g))
  d$R2 <- rbinom(n,1,fh_r(d$C1,d$C2))
  d$A2 <- ifelse(d$R2==1,sample_a(d$C2),0)
  d$C3 <- rbinom(n,1,fh_c(d$C2,d$A2,g))
  d$R3 <- rbinom(n,1,fh_r(d$C2,d$C3))
  complete <- d
  d$C2[d$R2==0] <- NA_real_; d$C3[d$R3==0] <- NA_real_
  list(observed=d, complete=complete)
}
fh_arguments <- function(g) list(trt=c("A1","A2"),outcome=c("C2","C3"),
  measurement=c("R1","R2","R3"), health=list("C1","C2","C3"), k=1,
  alpha=function(data,trt) rep(0,nrow(data)),
  d=local({mechanism<-g; function(data,trt) fh_d(data[[trt]],mechanism)}),
  t=local({mechanism<-g; function(data,trt,epsilon) {
    if(mechanism$type=="binary") as.numeric(epsilon<.35) else pmin(floor(4*epsilon),3)
  }}), mtp=g$type!="binary", bounds=c(-100,100))

# Independent forward causal enumeration, averaging over the visit process and
# the stochastic continuation law. No Monte Carlo truth is supplied to fitting.
fh_truth <- function(g) {
  answer <- c(0,0)
  for(c1 in 0:1) for(a1 in g$levels) for(c2 in 0:1) {
    a1d <- fh_d(a1,g)
    p <- .5*fh_g(c1,g)[a1+1]*dbinom(c2,1,fh_c(c1,a1d,g))
    answer[1] <- answer[1]+p*c2
    for(r2 in 0:1) for(a2 in g$levels) {
      probability <- if(r2==1) fh_g(c2,g)[a2+1] else g$continuation[a2+1]
      a2d <- if(r2==1) fh_d(a2,g) else a2
      answer[2] <- answer[2]+p*dbinom(r2,1,fh_r(c1,c2))*probability*fh_c(c2,a2d,g)
    }
  }
  answer
}
# Backward bridge functional, evaluated independently of the forward loop.
fh_backward_truth <- function(g) vapply(1:2,function(h) {
  sum(vapply(0:1,function(c1) .5*sum(vapply(g$levels,function(a1) {
    shifted <- fh_d(a1,g)
    m <- sum(vapply(0:1,function(c2) {
      if(h==1) q <- c2 else {
        beta <- 1/fh_r(c1,c2)
        md <- sum(fh_g(c2,g)*fh_c(c2,fh_d(g$levels,g),g))
        mt <- sum(g$continuation*fh_c(c2,g$levels,g))
        q <- fh_r(c1,c2)*(md+(beta-1)*mt)
      }
      dbinom(c2,1,fh_c(c1,shifted,g))*q
    },0))
    fh_g(c1,g)[a1+1]*m
  },0)),0))
},0)

fh_population <- function(g) {
  x <- expand.grid(C1=0:1,A1=g$levels,C2=0:1,R2=0:1,A2=g$levels,C3=0:1,R3=0:1)
  p <- .5*vapply(seq_len(nrow(x)),function(i) {
    a<-x[i,]
    pa2 <- if(a$R2==1) fh_g(a$C2,g)[a$A2+1] else as.numeric(a$A2==0)
    fh_g(a$C1,g)[a$A1+1]*dbinom(a$C2,1,fh_c(a$C1,a$A1,g))*
      dbinom(a$R2,1,fh_r(a$C1,a$C2))*pa2*dbinom(a$C3,1,fh_c(a$C2,a$A2,g))*
      dbinom(a$R3,1,fh_r(a$C2,a$C3))
  },0)
  x$p<-p; x[x$p>0,]
}
fh_validate <- function(g) {
  pop <- fh_population(g)
  stopifnot(abs(sum(pop$p)-1)<1e-12,
    max(abs(fh_truth(g)-fh_backward_truth(g)))<1e-12)
  # The bridge moments equal one in every instrument/state cell.
  b1 <- 1/fh_r(pop$C1,pop$C2); b2 <- 1/fh_r(pop$C2,pop$C3)
  moment <- function(B, weight, residual) {
    sums <- aggregate(cbind(weighted=weight*residual,mass=weight),list(cell=B),sum)
    max(abs(sums$weighted/sums$mass))
  }
  e1 <- moment(paste(pop$C1,pop$A1),pop$p,pop$R2*b1-1)
  e2 <- moment(paste(pop$C2,pop$A2),pop$p*pop$R2,pop$R3*b2-1)
  stopifnot(e1<1e-12,e2<1e-12)
  data.frame(mechanism=g$type, horizon=1:2,truth=fh_truth(g),
    bridge_moment_error=max(e1,e2),positivity_min=min(outer(0:1,0:1,fh_r)))
}

# Exact finite-support gradient check: solve each adjoint equation and verify
# the combined score and the mixed bridge-error remainder against population.
fh_gradient_check <- function(g) {
  p <- fh_population(g); w <- p$p
  ratio_d <- function(c,a) {
    probability <- fh_g(c,g)
    pushed <- vapply(g$levels,function(b) sum(probability[fh_d(g$levels,g)==b]),0)
    pushed[a+1]/probability[a+1]
  }
  rd1 <- mapply(ratio_d,p$C1,p$A1); rd2 <- mapply(ratio_d,p$C2,p$A2)
  rt2 <- mapply(function(c,a) g$continuation[a+1]/fh_g(c,g)[a+1],p$C2,p$A2)
  beta1 <- 1/fh_r(p$C1,p$C2); beta2 <- 1/fh_r(p$C2,p$C3)
  omega1 <- rd1; omega2 <- omega1*p$R2*(rd2+(beta1-1)*rt2)
  m2 <- function(c,a,delta2=0) sum(vapply(0:1,function(c3)
    dbinom(c3,1,fh_c(c,a,g))*fh_r(c,c3)*(1/fh_r(c,c3)+delta2)*c3,0))
  mt <- function(c,delta2=0) sum(g$continuation*vapply(g$levels,function(a) m2(c,a,delta2),0))
  md <- function(c,a,delta2=0) m2(c,fh_d(a,g),delta2)
  m1 <- function(c,a,delta1=0,delta2=0) sum(vapply(0:1,function(c2) {
    value <- sum(fh_g(c2,g)*vapply(g$levels,function(a2) md(c2,a2,delta2),0))+
      (1/fh_r(c,c2)+delta1-1)*mt(c2,delta2)
    dbinom(c2,1,fh_c(c,a,g))*fh_r(c,c2)*value
  },0))
  solve_adjoint <- function(s,loading) {
    cs <- p[[paste0('C',s)]]; aa <- p[[paste0('A',s)]]; nextc <- p[[paste0('C',s+1)]]
    J <- if(s==1) rep(1,nrow(p)) else p$R2
    complete <- J*p[[paste0('R',s+1)]]
    lambda <- numeric(nrow(p)); equation_error <- 0
    for(c in 0:1) {
      A <- matrix(0,2,length(g$levels)); phi <- numeric(2)
      for(cn in 0:1) {
        mass <- w*complete*(cs==c)*(nextc==cn); denominator<-sum(mass)
        A[cn+1,] <- vapply(g$levels,function(a) sum(mass*(aa==a))/denominator,0)
        phi[cn+1] <- sum(mass*loading)/denominator
      }
      coefficient <- as.numeric(t(A)%*%solve(tcrossprod(A),phi))
      equation_error <- max(equation_error,abs(A%*%coefficient-phi))
      lambda[cs==c] <- coefficient[p[[paste0('A',s)]][cs==c]+1]
    }
    list(value=lambda,error=equation_error)
  }
  adj1 <- solve_adjoint(1,omega1*mapply(mt,p$C2))
  adj2 <- solve_adjoint(2,omega2*p$C3)
  score <- function(delta) {
    bn1 <- beta1+delta; bn2<-beta2+delta
    om2 <- omega1*p$R2*(rd2+(bn1-1)*rt2)
    q2 <- p$R2*(mapply(function(c,a) md(c,a,delta),p$C2,p$A2)+
      (bn1-1)*vapply(p$C2,function(c) mt(c,delta),0))
    mn1 <- mapply(function(c,a) m1(c,a,delta,delta),p$C1,p$A1)
    md1 <- mapply(function(c,a) m1(c,fh_d(a,g),delta,delta),p$C1,p$A1)
    mn2 <- mapply(function(c,a) m2(c,a,delta),p$C2,p$A2)
    md1+omega1*(q2-mn1)+om2*(p$R3*bn2*p$C3-mn2)-
      adj1$value*(p$R2*bn1-1)-p$R2*adj2$value*(p$R3*bn2-1)
  }
  truth<-fh_truth(g)[2]; error0<-sum(w*score(0))-truth
  error1<-sum(w*score(.01))-truth;error2<-sum(w*score(.005))-truth
  stopifnot(abs(error0)<1e-11,adj1$error<1e-11,adj2$error<1e-11,
    abs(error2)<=.26*abs(error1)+1e-12)
  first_adjoint<-solve_adjoint(1,omega1*p$C2)
  first_mn<-fh_c(p$C1,p$A1,g);first_md<-fh_c(p$C1,fh_d(p$A1,g),g)
  first_score<-first_md+omega1*(p$R2*beta1*p$C2-first_mn)-
    first_adjoint$value*(p$R2*beta1-1)-fh_truth(g)[1]
  stopifnot(abs(sum(w*first_score))<1e-11,first_adjoint$error<1e-11)
  data.frame(mechanism=g$type,gradient_mean_error=error0,
    gradient_h1_mean_error=sum(w*first_score),
    adjoint_error=max(adj1$error,adj2$error,first_adjoint$error),bridge_error_001=error1,
    bridge_error_0005=error2,variance_reference_h1=sum(w*first_score^2),
    variance_reference_h2=sum(w*(score(0)-truth)^2))
}

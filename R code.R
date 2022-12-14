## Packages
require(R2jags)
require(survival)

## Application

# Dataset
data("retinopathy")
x 				    <- retinopathy

# Times
t1				    <- round(x$futime[x$trt == 1])
t2				    <- round(x$futime[x$trt == 0])

# Censoring
c1				    <- x$status[x$trt == 1]
c2				    <- x$status[x$trt == 0]

## Pre-data values
n             <- length(t1)
zeros         <- rep(0,n)

##===================================================##
##				                              	           ##
##   Marshall-Olkin Bivariate Sushila Distribution   ##
##					   	                                     ##
##===================================================##

# JAGS data
v1           <- ifelse(t1 > t2, 1, 0)
v2           <- ifelse(t1 < t2, 1, 0)
jags.data.sus<- c('t1','t2','c1','c2','v1','v2','n','zeros')

# JAGS parameters

jags.par.sus <- c('alpha1','alpha2','beta1','beta2','beta3', 
                  'phi11','phi10','phi01','phi00','rho1','rho2')

# JAGS inits

jags.inits.sus<- function()
{
  list('alpha1'=.1,'alpha2'=.1,
       'beta1'=.1,'beta2'=.1,'beta3'= .1,
       "rho1"=.6,"rho2"=.4)
}

# JAGS model
model.jags.sus<- 	function()
{
  eta <- g*(min(rho1,rho2) - rho1*rho2)
  phi01 <- rho1*(1-rho2) - eta
  phi10 <- (1-rho1)*rho2 - eta
  phi11 <- (1-rho1)*(1-rho2) + eta
  phi00 <- rho1 * rho2 + eta
  
  for (i in 1:n) 
  {
    phi[i]  <- -log(L[i]) 
    zeros[i]~dpois(phi[i])
    
    ## Auxiliary variables (Sushila pdfs)
    fl1[i]  <- beta1^2/(alpha1*(1 + beta1)) * (1 + t1[i]/alpha1) * exp(-beta1/alpha1 * t1[i])
    fl2[i]  <- beta2^2/(alpha2*(1 + beta2)) * (1 + t2[i]/alpha2) * exp(-beta2/alpha2 * t2[i])
    fl3[i]  <- beta3^2/(alpha1*(1 + beta3)) * (1 + t1[i]/alpha1) * exp(-beta3/alpha1 * t1[i])
    fl4[i]  <- beta3^2/(alpha2*(1 + beta3)) * (1 + t2[i]/alpha2) * exp(-beta3/alpha2 * t2[i])
    fl5[i]  <- beta2^2/(alpha2*(1 + beta2)) * (1 + t1[i]/alpha2) * exp(-beta2/alpha2 * t1[i])
    
    fe1[i]  <- (beta1 + beta3) * exp(-(beta1 + beta3) * t1[i])
    fe2[i]  <- (beta2 + beta3) * exp(-(beta2 + beta3) * t2[i])
    fe3[i]  <- beta3 * exp(-beta3 * t1[i])
    fe4[i]  <- beta3 * exp(-beta3 * t2[i])
    
    ## Auxiliary variables (Sushila sfs)
    se1[i]  <- exp(-(beta1 + beta3) * t1[i])
    se2[i]  <- exp(-(beta2 + beta3) * t2[i])
    se3[i]  <- exp(-(beta3) * t1[i])
    se4[i]  <- exp(-(beta3) * t2[i])
    
    sl1[i]  <- (alpha1*(1+beta1) + beta1*t1[i])/(alpha1 * (1 + beta1)) * exp(-beta1/alpha1 * t1[i])
    sl2[i]  <- (alpha2*(1+beta2) + beta2*t2[i])/(alpha1 * (1 + beta2)) * exp(-beta2/alpha2 * t2[i])
    sl3[i]  <- (alpha2*(1+beta2) + beta2*t1[i])/(alpha1 * (1 + beta2)) * exp(-beta2/alpha2 * t1[i])
    
    #######################################################################
    
    M1[i] <- sl1[i] * se3[i]
    M2[i] <- sl2[i] * se4[i]
    
    ######################
    ## Part 1
    A1[i]   <-  phi11 * (fl2[i] * (beta1 * (1 + t1[i])/(1 + beta1) * fe1[i] + beta3/(1 + beta1) * se1[i]))
    A2[i]   <-  phi11 * (fl1[i] * (beta2 * (1 + t2[i])/(1 + beta2) * fe2[i] + beta3/(1 + beta2) * se2[i]))
    A3[i]   <-  phi11 * (fe3[i] * sl1[i] * sl3[i])
    
    ## Part 2
    B1[i] <- phi11 * (fl1[i] * sl2[i] * se3[i] + sl1[i] * sl2[i] * fe3[i]) + phi10 * (fl1[i] * se3[i] + fe3[i] * sl1[i])
    B2[i] <- phi11 * (fl1[i] * sl2[i] * se4[i]) + phi10 * (fl1[i] * se3[i] + fe3[i] * sl1[i])
    B3[i] <- phi11 * (fl1[i] * sl3[i] * se1[i] + sl1[i] * (fl3[i] * se1[i] + fe1[i] * sl3[i])) + phi10 * (fl1[i] * se3[i] + fe3[i] * sl1[i]) + 
             phi01 * (fl5[i] * se3[i] + fe3[i] * sl3[i])
    
    # Part 3
    C1[i] <- phi11 * (sl1[i] * fl2[i] * se3[i]) + phi01 * (fl2[i] * se4[i] + fe4[i] * sl2[i])
    C2[i] <- phi11 * (fl2[i] * sl1[i] * se4[i] + sl1[i] * sl2[i] * fe4[i]) + phi01 * (fl2[i] * se4[i] + fe4[i] * sl2[i])
    
    # Part 4
    D1[i] <- phi11 * sl1[i] * sl2[i] * se3[i] + phi10 * M1[i] + phi01 * M2[i] + phi00
    D2[i] <- phi11 * sl1[i] * sl2[i] * se4[i] + phi10 * M1[i] + phi01 * M2[i] + phi00
    D3[i] <- phi11 * sl1[i] * sl3[i] * se3[i] + phi10 * M1[i] + phi01 * M2[i] + phi00
    
    ## Log-Likehoood 
    P1[i] <- v1[i]*(1 - v2[i]) * c1[i] * c2[i] * log(A1[i]) + v2[i]*(1 - v1[i]) * c1[i] * c2[i] * log(A2[i]) + (1 - v1[i])*(1 - v2[i]) * c1[i] * c2[i] * log(A3[i])
    P2[i] <- v1[i]*(1 - v2[i]) * c1[i] * (1 - c2[i]) * log((B1[i])) + v2[i]*(1 - v1[i]) * c1[i] * (1 - c2[i]) * log((B2[i])) + 
             (1 - v1[i])*(1 - v2[i]) * c1[i] * (1 - c2[i]) * log((B3[i]))
    P3[i] <- v1[i]*(1 - v2[i]) * (1 - c1[i]) * c2[i] * log((C1[i])) + v2[i]*(1 - v1[i]) * (1 - c1[i]) * c2[i] * log((C2[i]))
    P4[i] <- v1[i]*(1 - v2[i]) * (1 - c1[i]) * (1 - c2[i]) * log((D1[i])) + v2[i]*(1 - v1[i]) * (1 - c1[i]) * (1 - c2[i]) * log((D2[i])) + 
             (1 - v1[i])*(1 - v2[i]) * (1 - c1[i]) * (1 - c2[i]) * log((D3[i]))
    
    L[i]  <- exp(P1[i] + P2[i] + P3[i] + P4[i])
    
    ## Marginal survival for KM
    #Surv1[i]      <- phi00 + phi01 + (1 - phi00 - phi01) * M1[i]
    #Surv2[i]      <- phi00 + phi10 + (1 - phi00 - phi10) * M2[i]
  }
  
  ## Priors
  beta1~dgamma(.01,.01)
  beta2~dgamma(.01,.01)
  beta3~dgamma(.01,.01)
  alpha1~dgamma(.01,.01)
  alpha2~dgamma(.01,.01)
  rho1~dbeta(1,1)
  rho2~dbeta(1,1)
  g~dbeta(1,1)
}

## Results and Traceplots
es1    <- jags(data = jags.data.sus, inits = jags.inits.sus, 
                parameters.to.save = jags.par.sus, 
                model.file = model.jags.sus, 
                n.iter = 210000, n.burnin = 10000, n.thin = 100, 
                n.chain = 1)
fit.mcmc <- as.mcmc(est)

par(mfrow=c(4,3)) 
par(mar = c(4,4.6,4,1))
traceplot(fit.mcmc[,1][[1]],main=expression(alpha[1]),cex.main=1.5)
abline(h=0.66,col="red",lwd=2)
traceplot(fit.mcmc[,2][[1]],main=expression(alpha[2]),cex.main=1.5)
abline(h=0.94,col="red",lwd=2)
traceplot(fit.mcmc[,3][[1]],main=expression(theta[1]),cex.main=1.5)
abline(h=0.068,col="red",lwd=2)
traceplot(fit.mcmc[,4][[1]],main=expression(theta[2]),cex.main=1.5)
abline(h=0.071,col="red",lwd=2)
traceplot(fit.mcmc[,5][[1]],main=expression(theta[3]),cex.main=1.5)
abline(h=0.011,col="red",lwd=2)
traceplot(fit.mcmc[,7][[1]],main=expression(phi["00"]),cex.main=1.5)
abline(h=0.36,col="red",lwd=2)
traceplot(fit.mcmc[,8][[1]],main=expression(phi["01"]),cex.main=1.5)
abline(h=0.31,col="red",lwd=2)
traceplot(fit.mcmc[,9][[1]],main=expression(phi["10"]),cex.main=1.5)
abline(h=0.08,col="red",lwd=2)
traceplot(fit.mcmc[,10][[1]],main=expression(phi[11]),cex.main=1.5)
abline(h=0.25,col="red",lwd=2)
traceplot(fit.mcmc[,11][[1]],main=expression(rho[1]),cex.main=1.5)
abline(h=0.67,col="red",lwd=2)
traceplot(fit.mcmc[,12][[1]],main=expression(rho[2]),cex.main=1.5)
abline(h=0.42,col="red",lwd=2)

round(est1$BUGSoutput$summary[(n+1):(n+12),],4)

L<-est1$BUGSoutput$summary[1:n,1]
LPML<-sum(log(1/L)); LPML

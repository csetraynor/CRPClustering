#-----------------------------------------------------------------------Welcome
#               Chinese Restaurant Process Clustering
#                                                                    2017/11/01
#                                                                 Masashi Okada
#                                                      okadaalgorithm@gmail.com
#
#
#
# Description: Chinese Restaurant Process is used in order to compose Dirichlet
# Process. The Clustering which uses Chinese Restaurant Process does not need to
# decide a number of clusters in advance. This algorithm automatically adjusts
# it. And this package calculates ambiguity as entropy.

#---------------------------------------------------------------------------End

#-----------------------------------------------------------------------Library
library(MASS)
library(mvtnorm)
library(randomcoloR)
#---------------------------------------------------------------------------End

#' Markov chain Monte Carlo methods for CRP clustering
#' @import MASS
#' @import mvtnorm
#' @import stats
#' @import grid
#' @importFrom utils read.table
#' @param data : a matrix of data for clustering. Row is each data_i and column is dimensions of each data_i.
#' @param mu : a vector of center points of data. If data is 3 dimensions, a vector of 3 elements like c(2,4,2).
#' @param sigma : a numeric of data variance.
#' @param sigma_table : a numeric of CRP variance.
#' @param alpha : a numeric of a CRP concentrate rate.
#' @param ro_0 : a numeric of a CRP mu change rate.
#' @param burn_in :  an iteration integer of burn in.
#' @param iteration : an iteration integer.
#' @return z_result : a vector expresses cluster numbers for each data_i.
#' @examples
#' z_result <- crp_gibbs(matrix(c(0.1,0.1,0.2,0.2,0.3,0.3,1.4,1.4,1.5,1.5),2,2),
#'  mu=c(0,0), sigma=0.5, sigma_table=12, alpha=1, ro_0=0.1, burn_in=10, iteration=100)
#' @export
crp_gibbs<- function(data, mu=c(0,0), sigma=0.5, sigma_table=12, alpha=1, ro_0=0.1, burn_in=10, iteration=100) {

  data_length <- nrow(data)
  dim <- ncol(data)

  mu_0 <- mu
  sigma_0_c <- rep(c(sigma,rep(0,dim)),dim)
  sigma_0 <- matrix(sigma_0_c, dim, dim)
  sigma_new_c <- rep(c(sigma_table,rep(0,dim)),dim)
  sigma_new <- matrix(sigma_new_c, dim, dim)

  data_k <- array(0,dim=c(2, dim))

  mu_k <- array(0,dim=c(2, dim))
  z <- array(0,dim=c(iteration, data_length))
  z_result <- array(0,dim=c(data_length))
  n_k <- array()
  entropy_all <- 0
  k <- 0
  k_total <- 0
  K_count <- 0

  t <- 1

  prob_k <- NULL
  prob_k_CRP <- NULL

  for(i in 1 : data_length) {
    if(i == 1) {
      z[1,1] <- 1
      sample <- mvrnorm(1, mu_0, sigma_new)
      mu_k[1,] <- sample
      n_k[1] <- 1
      data_k[1,] <- data_k[1,] + data[1,]
      K_count <- 1
    }
    else {
      for(j in 1 : K_count){
        prob_k[j] <- dmvnorm(x=data[i,], mean=mu_k[j,])
        prob_k_CRP[j] <- n_k[j] / (data_length + alpha)
        prob_k[j] <- prob_k[j] * prob_k_CRP[j]
      }
      mu_k[K_count+1,] <- mvrnorm(1, mu_0, sigma_new)
      prob_k[K_count+1] <- dmvnorm(data[i,], mu_k[K_count+1,],sigma_0)
      prob_k[K_count+1] <- prob_k[K_count+1] * (alpha / (data_length + alpha))
      sample <- NULL
      sample <- rmultinom(1, size=1, prob=prob_k)
      K_count_now <- K_count + 1
      for(k in 1:K_count_now){
        if(sample[k,1] == 1){
          if(K_count_now == k){
            K_count <- K_count + 1
            data_k <- rbind(data_k, array(0,dim=c(1, dim)))
            mu_k <- rbind(mu_k, array(0,dim=c(1, dim)))

            n_k[k] <- 0
          }
          z[1,i] <- k
          data_k[k,] <- data_k[k,] + data[i,]
          n_k[k] <- n_k[k] + 1
          break
        }
      }
      prob_k <- NULL
      prob_k_CRP <- NULL
    }
    for(j in 1 : K_count){
      mu_k[j ,] <- mvrnorm(1, n_k[j] / (n_k[j] + ro_0) * (data_k[j,] / n_k[j]) + ro_0 / (n_k[j] + ro_0) * mu_0, sigma_0)
    }
  }
  for(t in 2 : iteration){
    for(i in 1 : data_length){
      data_k[z[t-1,i],] <- data_k[z[t-1,i],] - data[i,]
      n_k[z[t-1,i]] <- n_k[z[t-1,i]] - 1
      for(j in 1 : K_count){
        if(n_k[j] == 0){
          prob_k[j] <- 0
          next
        }
        prob_k[j] <- dmvnorm(x=data[i,], mean=mu_k[j,],sigma_0)
        prob_k_CRP[j] <- n_k[j] / (data_length - 1 + alpha)
        prob_k[j] <- prob_k[j] * prob_k_CRP[j]
      }
      mu_k[K_count+1,] <- mvrnorm(1, mu_0, sigma_new)
      prob_k[K_count+1] <- dmvnorm(data[i,], mu_k[K_count+1,])
      prob_k[K_count+1] <- prob_k[K_count+1] * (alpha / (data_length - 1 + alpha))
      sample <- NULL
      sample <- rmultinom(1, size=1, prob=prob_k)
      K_count_now <- K_count + 1
      for(k in 1 : K_count_now){
        if(sample[k,1] == 1){
          z[t,i] <- k
          n_k[k] <- n_k[k] + 1
          data_k[k,] <- data_k[k,] + data[i,]
          if(K_count_now == k){
            n_k[k] <- 1
            K_count <- K_count + 1
            data_k <- rbind(data_k, array(0,dim=c(1, dim)))
            mu_k <- rbind(mu_k, array(0,dim=c(1, dim)))
          }
          break
        }
      }
      prob_k <- NULL
      prob_k_CRP <- NULL
    }
    for(j in 1 : K_count){
      if(n_k[j] == 0){
        next
      }
      mu_k[j ,] <- mvrnorm(1, n_k[j] / (n_k[j] + ro_0) * (data_k[j,] / n_k[j]) + ro_0 / (n_k[j] + ro_0) * mu_0, sigma_0)
    }
    print(paste("iteration : ", t))
  }
  z_count <- array(0,dim=c(data_length, K_count + 1))
  for(i in 1 : data_length){
    for(t in burn_in : iteration){
      z_count[i, z[t, i]] <- z_count[i, z[t, i]] + 1
    }
    z_result[i] <- which.max(z_count[i, ])
  }

  n_k_result <- array(0,dim=c(K_count + 1))
  for(i in 1 : data_length){
      n_k_result[z_result[i]] <- n_k_result[z_result[i]] + 1
  }
  k_total <- 0
  for(j in 1 : K_count) {
    if(n_k_result[j] != 0){
       entropy_all <- entropy_all + (n_k_result[j] / data_length) * log2(n_k_result[j] / data_length)
       k_total <- k_total + 1
    }
  }
  print(paste("Entropy All : ", -1 * entropy_all))
  print(paste("The Number of Total Clusters  : ", k_total))
  return(invisible(z_result))
}

#' CRP clustering visualization
#' @import randomcoloR
#' @import graphics
#' @import stats
#' @param data : a matrix of data for clustering. Row is each data_i and column is dimensions of each data_i.
#' @param z_result : a vector denotes the number of a cluster for each data_i and it is the output of the method "crp_gibbs".
#' @examples
#' crp_graph_2d(matrix(c(0.1,0.1,0.2,0.2,0.3,0.3,1.4,1.4,1.5,1.5),2,2), c(1,1,2,2,2))
#' @export
crp_graph_2d<- function(data, z_result) {
  k_sort <- sort(unique(z_result))
  color <- array(0,dim=c(max(unique(z_result))))
  for(i in 1 : length(sort(unique(z_result)))){
    color[k_sort[i]] <- i
  }
  cols <- distinctColorPalette(k=length(unique(z_result)))
  for(i in 1 : nrow(data)){
    if(i == 1){
      data_plot <- data[i,]
      plot(data_plot[1],data_plot[2],col=cols[color[z_result[i]]],pch=20,cex=0.4,xlim=c(-2,2), ylim=c(-2,2),xlab="" , ylab="" , main="Clustering Result")
      par(new=T)
    }
    else{
      data_plot <- data[i,]
      plot(data_plot[1],data_plot[2],col=cols[color[z_result[i]]],pch=20,cex=0.4,xlim=c(-2,2), ylim=c(-2,2),xlab="" , ylab="" , main="",xaxt="n", yaxt="n")
      par(new=T)
    }
  }
}
#!/usr/bin/env Rscript

# Create some synthetic data for illustrating concepts in chapter 01.

# Simulation -------------------------------------------------------------------

set.seed(12345)
create_exp_mat <- function(n1, n2, ng,
                           alpha_mean, beta_mean, epsilon_sd) {
  status <- c(rep(0, n1), rep(1, n2))
  ns <- length(status)
  status <- matrix(status, nrow = 1)

  alpha <- rnorm(ng, mean = alpha_mean, sd = 1)
  beta <- matrix(rnorm(ng, mean = beta_mean, sd = 1), ncol = 1)
  epsilon <- matrix(rnorm(ng * ns, mean = 0, sd = epsilon_sd),
                    nrow = ng, ncol = ns)
  Yg <- alpha + beta %*% status + epsilon
  return(Yg)
}

gexp <- rbind(
  # 30 non-DE genes with high variance
  create_exp_mat(n1 = 3, n2 = 3, ng = 30, alpha_mean = 10, beta_mean = -1:1, epsilon_sd = 3),
  # 30 non-DE genes with low variance
  create_exp_mat(n1 = 3, n2 = 3, ng = 30, alpha_mean = 10, beta_mean = -1:1, epsilon_sd = 1),
  # 10 upregulated DE genes with low variance
  create_exp_mat(n1 = 3, n2 = 3, ng = 10, alpha_mean = 10, beta_mean = 5, epsilon_sd = 1),
  # 10 upregulated DE genes with high variance
  create_exp_mat(n1 = 3, n2 = 3, ng = 10, alpha_mean = 10, beta_mean = 5, epsilon_sd = 3),
  # 10 downregulated DE genes with low variance
  create_exp_mat(n1 = 3, n2 = 3, ng = 10, alpha_mean = 10, beta_mean = -5, epsilon_sd = 1),
  # 10 downregulated DE genes with high variance
  create_exp_mat(n1 = 3, n2 = 3, ng = 10, alpha_mean = 10, beta_mean = -5, epsilon_sd = 3)
)
image(t(gexp))

# Add names for samples
group <- rep(c("con", "treat"), each = ncol(gexp) / 2)
samples <- paste0(group, 1:3)
colnames(gexp) <- samples

# Add names for genes
genes <- sprintf("gene%02d", 1:nrow(gexp))
rownames(gexp) <- genes

saveRDS(gexp, "../data/ch01.rds")

# Analysis ---------------------------------------------------------------------

# limma
library("limma")
design <- model.matrix(~group)
colnames(design) <- c("Intercept", "treat")
fit <- lmFit(gexp, design)
head(fit$coefficients)
fit <- eBayes(fit)
results <- decideTests(fit[, 2])
summary(results)
stats <- topTable(fit, coef = "treat", number = nrow(fit), sort.by = "none")

# lm
lm_beta <- numeric(length = nrow(gexp))
lm_se <- numeric(length = nrow(gexp))
lm_p <- numeric(length = nrow(gexp))
for (i in 1:length(lm_p)) {
  mod <- lm(gexp[i, ] ~ group)
  result <- summary(mod)
  lm_beta[i] <- result$coefficients[2, 1]
  lm_se[i] <- result$coefficients[2, 2]
  lm_p[i] <- result$coefficients[2, 4]
}

stats <- cbind(stats,
               sd = apply(gexp, 1, sd),
               var = apply(gexp, 1, var),
               lm_beta, lm_se,
               lm_p = p.adjust(lm_p, method = "BH"))

stats$labels_pre <- c(rep("non-DE; high-var", 30),
                      rep("non-DE; low-var", 30),
                      rep("DE-up; low-var", 10),
                      rep("DE-up; high-var", 10),
                      rep("DE-down; low-var", 10),
                      rep("DE-down; high-var", 10))

stats$labels <- rep("non-DE", nrow(stats))
stats$labels[stats$adj.P.Val < 0.05 & stats$lm_p < 0.05] <- "DE"
stats$labels[stats$adj.P.Val < 0.05 & stats$lm_p >= 0.05] <- "limma-only"
stats$labels[stats$adj.P.Val >= 0.05 & stats$lm_p < 0.05] <- "lm-only"
table(stats$labels)
table(stats$labels, stats$labels_pre)

saveRDS(stats, "../data/ch01-stats.rds")

stopifnot(stats$logFC == stats$lm_beta)

de <- data.frame(effect_size = stats$lm_beta,
                 std_dev = stats$sd,
                 lm = stats$lm_p < 0.05,
                 limma = stats$adj.P.Val < 0.05)

saveRDS(de, "../data/de.rds")

# Example genes ----------------------------------------------------------------

library("dplyr")
library("tidyr")
library("stringr")

# Find a good example of a DE gene
index <- which(stats$labels_pre == "DE-up; low-var" & stats$labels == "DE")[1]
single_gene <- gexp %>% as.data.frame %>%
  slice(index) %>%
  gather(key = "group", value = "gene") %>%
  mutate(group = str_extract(group, "[a-z]*")) %>%
  as.data.frame()

saveRDS(single_gene, "../data/single_gene.rds")

# Find a gene that is DE for both, DE for lm-only, and DE for limma-only
de_not <- de_lm <- which(stats$labels == "non-DE" &
                           stats$labels_pre == "non-DE; high-var" &
                           stats$logFC > 0)[1]
de_both <- which(stats$labels == "DE" &
                   stats$labels_pre == "DE-up; low-var")[1]
de_lm <- which(stats$labels == "lm-only" &
                 stats$labels_pre == "non-DE; low-var" &
                 stats$logFC > 0)[1]
de_limma <- which(stats$labels == "limma-only" &
                    stats$labels_pre == "DE-up; high-var")[1]

compare <- gexp %>%
  as.data.frame() %>%
  slice(c(de_not, de_both, de_lm, de_limma)) %>%
  mutate(type = c("neither", "both", "lm-only", "limma-only")) %>%
  gather(key = "group", value = "gene", con1:treat3) %>%
  mutate(group = str_extract(group, "[a-z]*")) %>%
  as.data.frame()

saveRDS(compare, "../data/compare.rds")

# Visualization ----------------------------------------------------------------

library("ggplot2")

ggplot(stats, aes(x = sd, y = lm_beta, color = labels)) +
  geom_point()

ggplot(stats, aes(x = sd, y = lm_beta, color = lm_p < 0.05)) +
  geom_point()

ggplot(stats, aes(x = sd, y = logFC, color = labels)) +
  geom_point()

ggplot(stats, aes(x = logFC, y = -log10(P.Value), color = labels)) +
  geom_point()

ggplot(stats, aes(x = logFC, y = -log10(lm_p), color = labels)) +
  geom_point()

ggplot(stats, aes(x = sd, y = logFC, color = adj.P.Val < 0.05)) +
  geom_point()
ggplot(stats, aes(x = sd, y = logFC, color = lm_p < 0.05)) +
  geom_point()
plot(stats$adj.P.Val, stats$lm_p)
table(limma = stats$adj.P.Val < 0.05, lm = stats$lm_p < 0.05)
which(stats$adj.P.Val < 0.05)
which(stats$lm_p < 0.05)



ggplot(stats, aes(x = logFC, y = -log10(P.Value), color = adj.P.Val < 0.05)) +
  geom_point()
ggplot(stats, aes(x = logFC, y = -log10(P.Value), color = lm_p < 0.05)) +
  geom_point()

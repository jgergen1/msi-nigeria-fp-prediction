## Regenerates results/coefficients_*.csv and results/model_comparison.md from
## scratch. Run from the repo root, with pma_expanded_predictors.csv (see
## README for how to obtain it) also placed in the repo root.
suppressWarnings(suppressMessages({
  library(dplyr); library(rpart); library(randomForest); library(gbm); library(pROC)
}))

outdir <- "results"
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

## source the data-prep + model-fitting functions from 01_fit_models_and_plots.R
## without re-running its plotting calls at the bottom
src <- readLines("scripts/01_fit_models_and_plots.R")
cut <- grep("^res_unmet <-", src)[1]
eval(parse(text = paste(src[1:(cut - 1)], collapse = "\n")), envir = .GlobalEnv)

res_unmet <- run_model_womanlevel("unmettot", "UNMET NEED", CAND_FORM_RHS_UNMET, need_fp_ever_used = TRUE)
res_mcp   <- run_model_womanlevel("mcp", "CONTRACEPTIVE USE", CAND_FORM_RHS_MCP, need_fp_ever_used = FALSE)

write.csv(res_unmet$out, file.path(outdir, "coefficients_unmet_need.csv"), row.names = FALSE)
write.csv(res_mcp$out,   file.path(outdir, "coefficients_contraceptive_use.csv"), row.names = FALSE)

## ---- model comparison table (logistic / tree / RF / GBM) ----
metrics_from_prob <- function(actual01, prob, thresh = 0.5) {
  pred <- as.integer(prob >= thresh)
  tp <- sum(pred==1 & actual01==1); fp <- sum(pred==1 & actual01==0)
  tn <- sum(pred==0 & actual01==0); fn <- sum(pred==0 & actual01==1)
  acc <- (tp+tn)/length(actual01)
  prec <- if ((tp+fp)==0) NA else tp/(tp+fp)
  rec  <- if ((tp+fn)==0) NA else tp/(tp+fn)
  f1   <- if (is.na(prec)||is.na(rec)||(prec+rec)==0) NA else 2*prec*rec/(prec+rec)
  auc  <- as.numeric(pROC::auc(pROC::roc(actual01, prob, quiet = TRUE)))
  c(Accuracy=acc, Precision=prec, Recall=rec, F1=f1, `AUC-ROC`=auc)
}

run_outcome <- function(outcome_col, rhs, need_fp_ever_used, seed = 42) {
  dd <- d %>% filter(!is.na(.data[[outcome_col]]), .data[[outcome_col]] %in% c(0,1))
  dd <- prep(dd)
  dd[[paste0(outcome_col,"_f")]] <- factor(dd[[outcome_col]], levels = c(0,1))
  dd <- complete_case(dd, need_fp_ever_used)
  set.seed(seed)
  ids <- unique(dd$female_ID)
  train_ids <- sample(ids, size = round(0.8 * length(ids)))
  dd$split <- ifelse(dd$female_ID %in% train_ids, "train", "test")
  train <- dd %>% filter(split == "train")
  test  <- dd %>% filter(split == "test")
  actual01 <- as.integer(as.character(test[[paste0(outcome_col,"_f")]]))
  prevalence <- mean(actual01)
  form_f <- as.formula(paste0(outcome_col, "_f ~ ", rhs))
  results <- list()
  m <- glm(form_f, data = train, family = binomial())
  p <- predict(m, newdata = test, type = "response")
  results[["Logistic Regression"]] <- metrics_from_prob(actual01, p)
  m <- rpart(form_f, data = train, method = "class")
  p <- predict(m, newdata = test, type = "prob")[,2]
  results[["Decision Tree"]] <- metrics_from_prob(actual01, p)
  set.seed(seed)
  m <- randomForest(form_f, data = train, ntree = 500)
  p <- predict(m, newdata = test, type = "prob")[,2]
  results[["Random Forest"]] <- metrics_from_prob(actual01, p)
  train_num <- train; train_num[[paste0(outcome_col,"_num")]] <- as.numeric(as.character(train[[paste0(outcome_col,"_f")]]))
  form_num <- as.formula(paste0(outcome_col, "_num ~ ", rhs))
  set.seed(seed)
  m <- gbm(form_num, data = train_num, distribution = "bernoulli", n.trees = 1000,
           interaction.depth = 3, shrinkage = 0.01, cv.folds = 5, verbose = FALSE)
  best_iter <- gbm.perf(m, method = "cv", plot.it = FALSE)
  p <- predict(m, newdata = test, n.trees = best_iter, type = "response")
  results[["Gradient Boosting"]] <- metrics_from_prob(actual01, p)
  tab <- do.call(rbind, results)
  tab <- round(tab, 3)
  list(table = tab, prevalence = prevalence, n_test = length(actual01))
}

ru <- run_outcome("unmettot", CAND_FORM_RHS_UNMET, TRUE)
rm_ <- run_outcome("mcp", CAND_FORM_RHS_MCP, FALSE)

to_md <- function(tab, title, n_test, prevalence) {
  hdr <- sprintf("### %s\nTest N = %d, prevalence = %.1f%%\n\n| Model | Accuracy | Precision | Recall | F1 | AUC-ROC |\n|---|---|---|---|---|---|\n",
                  title, n_test, 100*prevalence)
  rows <- paste(sprintf("| %s | %.3f | %.3f | %.3f | %.3f | %.3f |", rownames(tab), tab[,1], tab[,2], tab[,3], tab[,4], tab[,5]), collapse = "\n")
  paste0(hdr, rows, "\n")
}

md <- paste0(
  "# Model comparison\n\n",
  "Four models compared on the identical woman-level 80/20 split (`set.seed(42)`), 0.5 classification threshold.\n\n",
  to_md(ru$table, "Unmet need", ru$n_test, ru$prevalence), "\n",
  to_md(rm_$table, "Contraceptive use", rm_$n_test, rm_$prevalence)
)
writeLines(md, file.path(outdir, "model_comparison.md"))
cat("Wrote results/coefficients_*.csv and results/model_comparison.md\n")

## Fits logistic regression models for unmet need and modern contraceptive
## use on a woman-level 80/20 train/test split of PMA Nigeria data, and
## writes the beeswarm feature-contribution charts to results/figures/.
## Run from the repo root with pma_expanded_predictors.csv (see README.md
## for how to obtain it) placed in the repo root.
suppressWarnings(suppressMessages({
  library(dplyr); library(ggplot2); library(ggbeeswarm); library(pROC)
}))

d <- read.csv("pma_expanded_predictors.csv", stringsAsFactors = FALSE, na.strings = c("", "NA"))

prep <- function(d) {
  d %>%
    filter(!is.na(age), !is.na(marital_status), !is.na(religion)) %>%
    filter(marital_status %in% c(1, 2)) %>%
    filter(!(religion %in% c(-99, 96))) %>%
    mutate(
      religion = factor(ifelse(religion == 3, "islam", "other")),
      state = factor(state),
      in_union_type = factor(ifelse(marital_status == 1, "married", "partner")),
      phase = as.integer(phase), age = as.numeric(age),
      residence = factor(ifelse(ur == 1, "urban", ifelse(ur == 2, "rural", NA)), levels = c("urban","rural")),
      education = factor(case_when(school == 0 ~ "none", school == 1 ~ "primary", school == 2 ~ "secondary", school == 3 ~ "higher", TRUE ~ NA_character_), levels = c("none","primary","secondary","higher")),
      radio = ifelse(fp_ad_radio_12m %in% c(0,1), fp_ad_radio_12m, NA),
      tv = ifelse(fp_ad_tv_12m %in% c(0,1), fp_ad_tv_12m, NA),
      social_media = ifelse(fp_ad_social_12m %in% c(0,1), fp_ad_social_12m, NA),
      age_first_sex = ifelse(age_at_first_sex > 0 & age_at_first_sex < 50, age_at_first_sex, NA),
      fp_ever_used_c = ifelse(fp_ever_used %in% c(0,1), fp_ever_used, NA),
      heard_pill_c = ifelse(heard_pill %in% c(0,1), heard_pill, NA),
      heard_inject_c = ifelse(heard_injectables %in% c(0,1), heard_injectables, NA),
      heard_iud_c = ifelse(heard_IUD %in% c(0,1), heard_IUD, NA),
      heard_implant_c = ifelse(heard_implants %in% c(0,1), heard_implants, NA),
      heard_condom_c = ifelse(heard_male_condoms %in% c(0,1), heard_male_condoms, NA),
      side_effects_concern = ifelse(wge_fp_aut_sideeffects_disrupt %in% 1:5, as.integer(wge_fp_aut_sideeffects_disrupt <= 2), NA),
      parity = birth_events,
      wants_more_children = case_when(more_children == 1 ~ "wants_more", more_children %in% c(2,3) ~ "no_more_or_undecided", TRUE ~ NA_character_),
      wants_more_children = factor(wants_more_children, levels = c("no_more_or_undecided","wants_more"))
    )
}

CAND_FORM_RHS_UNMET <- "age + state + in_union_type + religion + residence + education + radio + tv + social_media + age_first_sex + fp_ever_used_c + heard_pill_c + heard_inject_c + heard_iud_c + heard_implant_c + heard_condom_c + side_effects_concern + parity + wants_more_children"
CAND_FORM_RHS_MCP <- "age + state + in_union_type + religion + residence + education + radio + tv + social_media + age_first_sex + heard_pill_c + heard_inject_c + heard_iud_c + heard_implant_c + heard_condom_c + side_effects_concern + parity + wants_more_children"

complete_case <- function(dd, need_fp_ever_used = TRUE) {
  dd <- dd %>% filter(!is.na(residence), !is.na(education), !is.na(radio), !is.na(tv), !is.na(social_media),
                !is.na(age_first_sex),
                !is.na(heard_pill_c), !is.na(heard_inject_c), !is.na(heard_iud_c), !is.na(heard_implant_c), !is.na(heard_condom_c),
                !is.na(side_effects_concern), !is.na(parity), !is.na(wants_more_children))
  if (need_fp_ever_used) dd <- dd %>% filter(!is.na(fp_ever_used_c))
  dd
}

group_of <- function(c) {
  if (grepl("^state", c)) return("State (Lagos vs Kano)")
  if (grepl("^in_union_type", c)) return("Union type")
  if (grepl("^religion", c)) return("Religion")
  if (grepl("^education", c)) return("Education level")
  if (grepl("^residence", c)) return("Residence (urban vs rural)")
  if (c == "age") return("Age")
  if (c == "radio") return("Radio FP exposure")
  if (c == "tv") return("TV FP exposure")
  if (c == "social_media") return("Social media FP exposure")
  if (c == "age_first_sex") return("Age at first sex")
  if (c == "fp_ever_used_c") return("Ever used FP before")
  if (c == "heard_pill_c") return("Knows the pill")
  if (c == "heard_inject_c") return("Knows injectables")
  if (c == "heard_iud_c") return("Knows IUD")
  if (c == "heard_implant_c") return("Knows implants")
  if (c == "heard_condom_c") return("Knows male condoms")
  if (c == "side_effects_concern") return("Confident side effects won't disrupt relationship")
  if (c == "parity") return("Number of living children (parity)")
  if (grepl("^wants_more_children", c)) return("Wants more children")
  c
}

run_model_womanlevel <- function(outcome_col, outcome_label, rhs, need_fp_ever_used = TRUE, seed = 42) {
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

  cat("\n===", outcome_label, "(woman-level 80/20) === Train N:", nrow(train), "(", length(unique(train$female_ID)), "women ) Test N:", nrow(test), "(", length(unique(test$female_ID)), "women )\n")
  stopifnot(length(intersect(unique(train$female_ID), unique(test$female_ID))) == 0)

  form <- as.formula(paste0(outcome_col, "_f ~ ", rhs))
  m <- glm(form, data = train, family = binomial())
  actual <- as.numeric(as.character(test[[paste0(outcome_col,"_f")]]))
  p <- predict(m, newdata = test, type = "response")
  auc_val <- round(as.numeric(pROC::auc(pROC::roc(actual, p, quiet = TRUE))), 3)
  cat("AUC:", auc_val, "\n")

  s <- summary(m)$coefficients
  or <- exp(cbind(OR=coef(m), confint.default(m)))
  out <- data.frame(term=rownames(s), estimate=round(s[,1],3), p=signif(s[,4],4), OR=round(or[,1],3), OR_lo=round(or[,2],3), OR_hi=round(or[,3],3))
  cat("--- Coefficients ---\n"); print(out, row.names = FALSE)

  sig_terms <- rownames(s)[s[,4] < 0.05]
  sig_groups <- unique(vapply(sig_terms, group_of, character(1)))

  mm_train <- model.matrix(form, data = train)[, -1, drop = FALSE]
  mm_test  <- model.matrix(form, data = test)[, -1, drop = FALSE]
  coefs <- coef(m)[-1]
  ref_means <- colMeans(mm_train)
  contrib <- sweep(mm_test, 2, ref_means, "-")
  contrib <- sweep(contrib, 2, coefs, "*")
  groups <- vapply(colnames(contrib), group_of, character(1))

  long <- do.call(rbind, lapply(unique(groups), function(g) {
    cols <- which(groups == g)
    cvals <- if (length(cols) == 1) contrib[, cols] else rowSums(contrib[, cols, drop = FALSE])
    raw <- if (length(cols) == 1) mm_test[, cols] else rowSums(mm_test[, cols, drop = FALSE])
    rr <- range(raw)
    rawscaled <- if (diff(rr) == 0) rep(0.5, length(raw)) else (raw - rr[1]) / diff(rr)
    data.frame(feature = g, contribution = cvals, value = rawscaled)
  }))
  ord <- long %>% group_by(feature) %>% summarise(m = mean(abs(contribution))) %>% arrange(m)
  ord$sig <- ord$feature %in% sig_groups
  ord$label <- ifelse(ord$sig, paste0(ord$feature, "  *"), ord$feature)

  list(long = long, ord = ord, auc = auc_val, test_n = nrow(test), train_n = nrow(train), sig_groups = sig_groups, model = m, out = out)
}

make_plot <- function(res, title, outpath, top_n = NULL, height = 8.5) {
  ord <- res$ord
  if (!is.null(top_n)) ord <- tail(ord, top_n)
  dd <- res$long %>% filter(feature %in% ord$feature)
  dd$label <- ord$label[match(dd$feature, ord$feature)]
  dd$label <- factor(dd$label, levels = ord$label)
  n_tested <- nrow(res$ord)
  subtitle <- sprintf("AUC %.3f — woman-level 80/20 split, test N = %d — %s of %d predictors tested — * p<0.05",
                       res$auc, res$test_n, if (!is.null(top_n)) paste("top", top_n) else "all", n_tested)
  p <- ggplot(dd, aes(x = contribution, y = label, color = value)) +
    geom_vline(xintercept = 0, color = "grey70", linewidth = 0.4) +
    geom_quasirandom(groupOnX = FALSE, size = 1.1, alpha = 0.65, width = 0.35) +
    scale_color_gradient(low = "#2c7fb8", high = "#d7301f", name = "Feature\nvalue",
                          breaks = c(0,1), labels = c("Low","High")) +
    labs(title = title, subtitle = subtitle, x = "Contribution to predicted log-odds", y = NULL) +
    theme_minimal(base_size = 11.5) +
    theme(panel.grid.major.y = element_blank(), plot.title = element_text(face = "bold"),
          plot.subtitle = element_text(size = 10.5))
  ggsave(outpath, p, width = 11.6, height = height, dpi = 200)
  cat("wrote", outpath, "\n")
}

dir.create("results/figures", showWarnings = FALSE, recursive = TRUE)

res_unmet <- run_model_womanlevel("unmettot", "UNMET NEED", CAND_FORM_RHS_UNMET, need_fp_ever_used = TRUE)
res_mcp   <- run_model_womanlevel("mcp", "CONTRACEPTIVE USE", CAND_FORM_RHS_MCP, need_fp_ever_used = FALSE)

make_plot(res_unmet, "What drives predicted unmet need?", "results/figures/unmet_need_beeswarm_top10.png", top_n = 10, height = 5.8)
make_plot(res_mcp,   "What drives predicted modern contraceptive use?", "results/figures/contraceptive_use_beeswarm_top10.png", top_n = 10, height = 5.8)

cat("\nDONE\n")

make_plot(res_unmet, "What drives predicted unmet need? (all predictors)", "results/figures/unmet_need_beeswarm_full.png", top_n = NULL, height = 8.7)
make_plot(res_mcp,   "What drives predicted modern contraceptive use? (all predictors)", "results/figures/contraceptive_use_beeswarm_full.png", top_n = NULL, height = 8.7)
cat("\nFULL CHARTS DONE\n")

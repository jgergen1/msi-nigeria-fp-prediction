# Predicting family planning outcomes in Nigeria from PMA survey data

Two logistic regression models that predict (1) unmet need for family planning and (2) modern contraceptive use among women of reproductive age in Nigeria, built on Performance Monitoring for Action (PMA) Nigeria survey data. Built by [Visualst](https://visualst.org) for MSI Reproductive Choices.

## Data

Source: [PMA Nigeria](https://www.pmadata.org/countries/nigeria), a household- and female-respondent-level panel survey. This repo does not include the underlying microdata — PMA data is available free of charge after registering and agreeing to PMA's data use terms at [pmadata.org](https://www.pmadata.org/data/request-access-datasets). To reproduce these results, download the relevant PMA Nigeria rounds, build a respondent-level extract with the variables referenced in `scripts/01_fit_models_and_plots.R`, and save it as `pma_expanded_predictors.csv` in the repo root.

**Important — this is a panel survey.** The same women are re-interviewed across PMA phases/rounds. A train/test split that puts earlier phases in training and a later phase in test will leak information: in this dataset, most respondents in the "test" phase had already appeared in training. All models here instead split **by woman** (every row for a given respondent goes entirely to train or entirely to test), which is the methodologically sound approach for panel data and is what the numbers below reflect.

Sample: married/in-union women of reproductive age, complete cases only (any row missing a predictor or outcome is dropped). The sample is unweighted — the percentages below describe this survey sample, not a population-representative estimate.

## Outcomes

- **Unmet need for family planning**: the standard DHS/PMA composite — fecund, married/in-union, doesn't want a(nother) child now, and not using any method (including traditional methods).
- **Modern contraceptive use**: currently using a modern method (not any method).

## Method

- 80/20 train/test split, grouped by woman (`female_ID`), `set.seed(42)`, so no respondent appears in both sets.
- Logistic regression (`glm`, binomial family) on each outcome, see `scripts/01_fit_models_and_plots.R` for the full predictor list and variable construction.
- Per-observation feature contribution: `coefficient × (observed value − training-set mean)` on the log-odds scale, summed by feature group, plotted as a beeswarm (`results/figures/`).
- Model choice was tested empirically, not assumed: logistic regression, a decision tree, a random forest, and gradient boosting were compared on the identical split (`results/model_comparison.md`). Logistic regression's AUC was competitive with or better than the alternatives on both outcomes, and it's the only one of the four that also returns interpretable, defensible coefficients (odds ratios and p-values) — which matters more for this use case than a marginal accuracy gain. That's why it's the model used throughout.

## Results

| Outcome | Test N (women) | AUC |
|---|---|---|
| Unmet need | 883 (427 women) | 0.681 |
| Contraceptive use | 887 (425 women) | 0.742 |

Full coefficient tables (odds ratios, 95% CI, p-values): `results/coefficients_unmet_need.csv`, `results/coefficients_contraceptive_use.csv`.

Full model comparison (Accuracy / Precision / Recall / F1 / AUC-ROC across all four models): `results/model_comparison.md`.

### Unmet need — what drives the prediction

![Unmet need beeswarm](results/figures/unmet_need_beeswarm_top10.png)

### Contraceptive use — what drives the prediction

![Contraceptive use beeswarm](results/figures/contraceptive_use_beeswarm_top10.png)

Full-predictor versions of both charts (all tested predictors, not just the top 10) are in `results/figures/`.

## Repo structure

```
scripts/
  01_fit_models_and_plots.R   # data prep, both models, beeswarm charts
  02_export_results.R         # coefficient tables + 4-model comparison table
results/
  coefficients_unmet_need.csv
  coefficients_contraceptive_use.csv
  model_comparison.md
  figures/                    # beeswarm charts (top-10 and full-predictor versions)
```

## Limitations

- Sample is unweighted; findings describe this survey sample, not a population estimate.
- AUCs (0.68–0.74) indicate meaningful but partial predictive power — these models flag relative risk, not individual-level certainty.
- Gradient boosting has no p-values; where it's used for comparison, "importance" means relative influence, a different concept from statistical significance.
- Associational, not causal — coefficients describe correlations controlling for the other predictors in the model, not causal effects.

## License

Code in this repo is MIT licensed (see `LICENSE`). PMA survey data is governed by PMA's own data use terms and is not included here.

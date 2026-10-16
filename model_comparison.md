# Model comparison

Four models compared on the identical woman-level 80/20 split (`set.seed(42)`), 0.5 classification threshold.

### Unmet need
Test N = 883, prevalence = 19.1%

| Model | Accuracy | Precision | Recall | F1 | AUC-ROC |
|---|---|---|---|---|---|
| Logistic Regression | 0.804 | 0.409 | 0.053 | 0.094 | 0.681 |
| Decision Tree | 0.809 | NA | 0.000 | NA | 0.500 |
| Random Forest | 0.804 | 0.400 | 0.047 | 0.085 | 0.652 |
| Gradient Boosting | 0.802 | 0.385 | 0.059 | 0.103 | 0.689 |

### Contraceptive use
Test N = 887, prevalence = 26.8%

| Model | Accuracy | Precision | Recall | F1 | AUC-ROC |
|---|---|---|---|---|---|
| Logistic Regression | 0.740 | 0.524 | 0.319 | 0.397 | 0.742 |
| Decision Tree | 0.740 | 0.516 | 0.471 | 0.492 | 0.718 |
| Random Forest | 0.741 | 0.523 | 0.387 | 0.444 | 0.738 |
| Gradient Boosting | 0.766 | 0.595 | 0.395 | 0.475 | 0.755 |


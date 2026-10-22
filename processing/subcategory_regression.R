# ==========================================
# Subcategory-Level Regression
#
# For each subcategory:
#   rating ~ <attribute>_attribute_score + <attribute>_attribute_coverage  (EVERY attribute of that subcategory)
# attribute_score    = mean (P(positive) - P(negative)) over sentences mentioning the attribute; 0 if not mentioned
# attribute_coverage = sentences mentioning the attribute / total sentences in review
#
# All 22 models are fitted in memory; only summary(model) of the 2 best is written to ./output.
# Selection = trade-off of fit and significance at 5%:
#   rank of adjusted R² + rank of share of predictors with p < 0.05, averaged -> lowest 2 selected
# Attributes with zero detections are kept; lm() reports NA for them (no variation to estimate an effect).
# Requires: review_df, attribute_df, attribute_set (from main.R) or the v2 CSVs
# ==========================================

library(dplyr)
library(tidyr)

SIGNIFICANCE_LEVEL = 0.05
TOP_N_MODELS = 2

fit_subcategory_model = function(model_df, subcategoryName) {

  subcategory_attributes = sort(unique(
    attribute_set$aspect[attribute_set$subcategory == subcategoryName]
  ))

  data = model_df %>%
    filter(subcategory == subcategoryName)

  # Every dictionary attribute of the subcategory, even if never detected
  data_wide = data %>%
    select(review_id, rating) %>%
    distinct() %>%
    crossing(attribute = subcategory_attributes) %>%
    left_join(
      data %>% select(review_id, attribute, attribute_score, attribute_coverage),
      by = c("review_id", "attribute")
    ) %>%
    mutate(
      attribute_score = coalesce(attribute_score, 0),
      attribute_coverage = coalesce(attribute_coverage, 0)
    ) %>%
    pivot_wider(
      names_from = attribute,
      values_from = c(attribute_score, attribute_coverage),
      names_glue = "{attribute}_{.value}"
    ) %>%
    select(-review_id)

  model = lm(rating ~ ., data = data_wide)

  return(model)
}

get_selection_table = function(models) {

  data.frame(
    subcategory = names(models),
    adj_r2 = sapply(models, function(m) summary(m)$adj.r.squared),
    significant_share = sapply(models, function(m) {
      p_values = summary(m)$coefficients[-1, 4]
      sum(p_values < SIGNIFICANCE_LEVEL) / (length(coef(m)) - 1)
    })
  ) %>%
    mutate(
      selection_score = (rank(-adj_r2) + rank(-significant_share)) / 2
    ) %>%
    arrange(selection_score, desc(adj_r2))
}

if (!exists("attribute_df")) {
  attribute_df = read.csv("./output/attribute_df_v2.csv")
}

if (!exists("review_df")) {
  review_df = read.csv("./datasets/final_reviews.csv") %>%
    mutate(review_id = row_number())
}

if (!exists("attribute_set")) {
  attribute_set = read.csv("./datasets/final_attributes.csv")
}

model_df = attribute_df %>%
  left_join(review_df %>% select(review_id, rating), by = "review_id")

subcategories = sort(unique(model_df$subcategory))

models = lapply(subcategories, function(sc) fit_subcategory_model(model_df, sc))
names(models) = subcategories

selected = head(get_selection_table(models)$subcategory, TOP_N_MODELS)

sink("./output/subcategory_regression_top2_v2.txt")
for (sc in selected) {
  cat("==========================================\n")
  cat("Subcategory:", sc, "\n")
  cat("==========================================\n")
  print(summary(models[[sc]]))
}
sink()

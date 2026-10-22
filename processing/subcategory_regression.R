# ==========================================
# Subcategory-Level Regression
#
# For each subcategory in REGRESSION_SUBCATEGORIES:
#   rating ~ <attribute>_attribute_score + <attribute>_attribute_coverage
# Unmentioned attribute -> score 0 (neutral); coverage is already 0
# ==========================================

fit_subcategory_model = function(attribute_df, review_df, subcategoryName) {

  data_wide = attribute_df %>%
    filter(subcategory == subcategoryName) %>%
    select(review_id, asin, subcategory, attribute,
           attribute_score, attribute_coverage) %>%
    pivot_wider(
      id_cols = c(review_id, asin, subcategory),
      names_from = attribute,
      values_from = c(attribute_score, attribute_coverage),
      names_glue = "{attribute}_{.value}"
    ) %>%
    mutate(across(ends_with("_score"), ~ replace_na(.x, 0))) %>%
    left_join(
      review_df %>% select(review_id, rating),
      by = "review_id"
    ) %>%
    select(-asin, -review_id, -subcategory)

  model = lm(rating ~ ., data = data_wide)

  return(model)
}

run_subcategory_regression = function(attribute_df, review_df) {

  models = list()

  for (sc in REGRESSION_SUBCATEGORIES) {

    models[[sc]] = fit_subcategory_model(attribute_df, review_df, sc)

    logger("==========================================\n")
    logger(paste("Subcategory:", sc, "\n"))
    logger("==========================================\n")
    print(summary(models[[sc]]))

    # Multicollinearity check: pairwise correlation of predictors
    cor_matrix = models[[sc]]$model %>%
      select(-rating) %>%
      cor(use = "pairwise.complete.obs")

    print(round(cor_matrix, 3))
  }

  return(models)
}

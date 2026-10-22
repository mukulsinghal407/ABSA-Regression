# ==========================================
# Subcategory-Level Regression
#
# For each subcategory:
#   rating ~ <attribute>_score + <attribute>_coverage  (for every attribute of that subcategory)
# attribute_score    = mean (P(positive) - P(negative)) over sentences mentioning the attribute; 0 if not mentioned
# attribute_coverage = sentences mentioning the attribute / total sentences in review
# Requires: review_df, attribute_df (from main.R) or the v2 CSVs in ./output
# ==========================================

library(dplyr)
library(tidyr)

run_subcategory_regression = function(review_df, attribute_df) {

  model_df = attribute_df %>%
    mutate(attribute_score = coalesce(attribute_score, 0)) %>%
    left_join(review_df %>% select(review_id, rating), by = "review_id")

  summaries = list()
  coefficients = list()

  for (sc in sort(unique(model_df$subcategory))) {

    wide = model_df %>%
      filter(subcategory == sc) %>%
      select(review_id, rating, attribute, attribute_score, attribute_coverage) %>%
      pivot_wider(
        names_from = attribute,
        values_from = c(attribute_score, attribute_coverage),
        names_glue = "{attribute}_{sub('attribute_', '', .value)}",
        values_fill = 0
      )

    predictors = setdiff(names(wide), c("review_id", "rating"))

    # Drop constant predictors (attribute never mentioned in this subcategory)
    predictors = predictors[sapply(wide[predictors], function(x) sd(x) > 0)]

    model = lm(
      reformulate(predictors, response = "rating"),
      data = wide
    )

    s = summary(model)

    summaries[[sc]] = data.frame(
      subcategory = sc,
      n_reviews = nrow(wide),
      n_predictors = length(predictors),
      r2 = s$r.squared,
      adj_r2 = s$adj.r.squared,
      f_pvalue = pf(s$fstatistic[1], s$fstatistic[2], s$fstatistic[3], lower.tail = FALSE),
      mean_rating = mean(wide$rating)
    )

    coef_table = as.data.frame(s$coefficients)[-1, , drop = FALSE]

    coefficients[[sc]] = data.frame(
      subcategory = sc,
      term = rownames(coef_table),
      estimate = coef_table[, 1],
      std_error = coef_table[, 2],
      p_value = coef_table[, 4]
    )
  }

  return(list(
    summary = bind_rows(summaries) %>% arrange(desc(adj_r2)),
    coefficients = bind_rows(coefficients)
  ))
}

if (!exists("attribute_df")) {
  attribute_df = read.csv("./output/attribute_df_v2.csv")
}

if (!exists("review_df")) {
  review_df = read.csv("./datasets/final_reviews.csv") %>%
    mutate(review_id = row_number())
}

regression_output = run_subcategory_regression(review_df, attribute_df)

write.csv(regression_output$summary, "./output/subcategory_regression_summary_v2.csv", row.names = FALSE)
write.csv(regression_output$coefficients, "./output/subcategory_regression_coefficients_v2.csv", row.names = FALSE)

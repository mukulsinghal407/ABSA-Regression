# ==========================================
# Visualisations (ggplot2)
# Every function takes one subcategory, e.g. "protection"
# Uses review_df, attribute_df, product_attribute_df from main.R
# Saves PNGs to ./output/graphs (file name ends with the subcategory)
# ==========================================

bar_number_of_reviews_per_aspect = function(subcategoryName){
  # Total number of reviews in the subcategory
  total_reviews = sum(review_df$subcategory == subcategoryName)

  # Calculate attribute frequency
  attribute_frequency = attribute_df %>%
    filter(
      subcategory == subcategoryName,
      attribute_count > 0
    ) %>%
    group_by(attribute) %>%
    summarise(
      review_count = n_distinct(review_id),
      .groups = "drop"
    ) %>%
    mutate(
      percentage = round(review_count / total_reviews * 100, 1)
    ) %>%
    arrange(desc(review_count))

  # Visualization
  bar_plot = ggplot(
    attribute_frequency,
    aes(
      x = reorder(attribute, review_count),
      y = review_count
    )
  ) +
    geom_col(fill = "steelblue") +
    geom_text(
      aes(label = paste0(review_count, " (", percentage, "%)")),
      hjust = 1.1,
      colour = "white",
      size = 3.5
    ) +
    coord_flip() +
    labs(
      title = paste("Number of Reviews Discussing Each Attribute:", subcategoryName),
      subtitle = paste("Total Reviews:", total_reviews),
      x = "Attribute",
      y = "Number of Reviews",
      caption = "Percentages represent the share of the subcategory's reviews mentioning each attribute."
    ) +
    theme_minimal()

  print(bar_plot)

  ggsave(
    filename = paste0("./output/graphs/bar_number_of_reviews_per_aspect_", subcategoryName, ".png"),
    plot = bar_plot,
    width = 10,
    height = 6,
    units = "in"
  )
}

bar_attribute_sentiment_summary = function(subcategoryName){
  # Prepare sentiment data
  sentiment_data = attribute_df %>%
    filter(
      subcategory == subcategoryName,
      attribute_count > 0,
      !is.na(attribute_score),
      attribute_score != 0
    ) %>%
    mutate(
      sentiment_type = ifelse(
        attribute_score > 0,
        "Positive",
        "Negative"
      )
    ) %>%
    group_by(attribute, sentiment_type) %>%
    summarise(
      avg_score = mean(attribute_score),
      review_count = n_distinct(review_id),
      .groups = "drop"
    )

  # Create visualization
  sentiment_plot = ggplot(
    sentiment_data,
    aes(
      x = attribute,
      y = avg_score,
      fill = sentiment_type
    )
  ) +
    geom_col(position = "identity", width = 0.7) +
    geom_text(
      aes(
        label = paste0(
          round(avg_score, 2),
          " (n=", review_count, ")"
        ),
        hjust = ifelse(avg_score > 0, 1.1, -0.1)
      ),
      colour = "white",
      size = 3.5
    ) +
    coord_flip() +
    scale_fill_manual(
      values = c(
        "Positive" = "steelblue",
        "Negative" = "tomato"
      )
    ) +
    labs(
      title = paste("Positive and Negative Sentiment by Attribute:", subcategoryName),
      subtitle = "Average sentiment scores and number of reviews",
      x = "Attribute",
      y = "Average Sentiment Score",
      fill = "Sentiment"
    ) +
    theme_minimal()

  print(sentiment_plot)

  ggsave(
    filename = paste0("./output/graphs/bar_attribute_sentiment_summary_", subcategoryName, ".png"),
    plot = sentiment_plot,
    width = 11,
    height = 6,
    units = "in"
  )
}

bar_attributes_discussed_per_review = function(subcategoryName){
  # Count attributes discussed in each review
  review_attribute_count = attribute_df %>%
    filter(subcategory == subcategoryName) %>%
    group_by(review_id) %>%
    summarise(
      attributes_discussed = sum(attribute_count > 0, na.rm = TRUE),
      .groups = "drop"
    )

  # Include all reviews of the subcategory, even those without attribute records
  subcategory_reviews = review_df %>%
    filter(subcategory == subcategoryName)

  review_attribute_count = subcategory_reviews %>%
    select(review_id) %>%
    left_join(
      review_attribute_count,
      by = "review_id"
    ) %>%
    mutate(
      attributes_discussed = coalesce(attributes_discussed, 0L)
    )

  # Count reviews for each number of attributes discussed
  attribute_distribution = review_attribute_count %>%
    count(attributes_discussed, name = "review_count") %>%
    mutate(
      percentage = round(
        review_count / sum(review_count) * 100, 1
      )
    )

  coverage_plot = ggplot(
    attribute_distribution,
    aes(
      x = factor(attributes_discussed),
      y = review_count
    )
  ) +
    geom_col(
      fill = "steelblue",
      width = 0.7
    ) +
    geom_text(
      aes(
        label = paste0(
          review_count, " (", percentage, "%)"
        )
      ),
      vjust = 1.5,
      colour = "white",
      size = 3.5
    ) +
    labs(
      title = paste("Number of Attributes Discussed per Review:", subcategoryName),
      subtitle = paste(
        "Total Reviews:", nrow(subcategory_reviews)
      ),
      x = "Number of Attributes Discussed",
      y = "Number of Reviews",
      caption = "Percentages represent the share of the subcategory's reviews."
    ) +
    theme_minimal()

  print(coverage_plot)

  ggsave(
    filename = paste0("./output/graphs/bar_attributes_discussed_per_review_", subcategoryName, ".png"),
    plot = coverage_plot,
    width = 11,
    height = 7,
    units = "in"
  )
}

bar_attributes_discussed_vs_rating = function(subcategoryName){
  # Count attributes discussed in each review
  review_attribute_count = attribute_df %>%
    filter(subcategory == subcategoryName) %>%
    group_by(review_id) %>%
    summarise(
      attributes_discussed = sum(attribute_count > 0, na.rm = TRUE),
      .groups = "drop"
    )

  # Join attribute counts with customer ratings (all reviews, 0 if none detected)
  rating_coverage_data = review_df %>%
    filter(subcategory == subcategoryName) %>%
    select(review_id, rating) %>%
    left_join(
      review_attribute_count,
      by = "review_id"
    ) %>%
    mutate(
      attributes_discussed = coalesce(attributes_discussed, 0L)
    )

  # Calculate average rating
  rating_coverage_summary = rating_coverage_data %>%
    group_by(attributes_discussed) %>%
    summarise(
      avg_rating = mean(rating),
      review_count = n(),
      .groups = "drop"
    ) %>%
    mutate(
      group_label = paste0(attributes_discussed, "\n(n=", review_count, ")"),
      group_label = factor(group_label, levels = group_label)
    )

  rating_coverage_plot = ggplot(
    rating_coverage_summary,
    aes(
      x = group_label,
      y = avg_rating
    )
  ) +
    geom_line(
      aes(group = 1),
      colour = "steelblue",
      linewidth = 1
    ) +
    geom_point(
      colour = "steelblue",
      size = 3
    ) +
    labs(
      title = paste("Average Customer Rating by Number of Attributes Discussed:", subcategoryName),
      subtitle = "Relationship between attribute coverage and customer ratings",
      x = "Number of Attributes Discussed",
      y = "Average Customer Rating",
      caption = "n = number of reviews in each group"
    ) +
    theme_minimal()

  print(rating_coverage_plot)

  ggsave(
    filename = paste0("./output/graphs/bar_attributes_discussed_vs_rating_", subcategoryName, ".png"),
    plot = rating_coverage_plot,
    width = 11,
    height = 7,
    units = "in"
  )
}

bar_distinct_products_per_subcategory = function(subcategoryName){
  # Number of distinct products whose reviews discuss each attribute
  products_per_attribute = product_attribute_df %>%
    filter(
      subcategory == subcategoryName,
      total_attribute_reviews > 0
    ) %>%
    group_by(attribute) %>%
    summarise(
      distinct_products = n_distinct(product_asin),
      .groups = "drop"
    )

  total_products = n_distinct(
    product_attribute_df$product_asin[product_attribute_df$subcategory == subcategoryName]
  )

  products_plot = ggplot(
    products_per_attribute,
    aes(
      x = reorder(attribute, distinct_products),
      y = distinct_products
    )
  ) +
    geom_col(fill = "steelblue", width = 0.7) +
    geom_text(
      aes(label = distinct_products),
      hjust = 1.2,
      colour = "white",
      size = 3.5
    ) +
    coord_flip() +
    labs(
      title = paste("Distinct Products Discussed per Attribute:", subcategoryName),
      subtitle = paste("Total Products:", total_products),
      x = "Attribute",
      y = "Number of Distinct Products"
    ) +
    theme_pander()

  print(products_plot)

  ggsave(
    filename = paste0("./output/graphs/bar_distinct_products_per_subcategory_", subcategoryName, ".png"),
    plot = products_plot,
    width = 10,
    height = 6,
    units = "in"
  )
}

bar_rating_by_mention_status = function(subcategoryName){
  # Average rating when an attribute is not mentioned, mentioned positively, or mentioned negatively
  mention_data = attribute_df %>%
    filter(subcategory == subcategoryName) %>%
    left_join(
      review_df %>%
        select(review_id, rating),
      by = "review_id"
    ) %>%
    mutate(
      mention_status = case_when(
        attribute_count == 0 ~ "Not mentioned",
        attribute_score > 0 ~ "Mentioned positive",
        TRUE ~ "Mentioned negative"
      ),
      mention_status = factor(
        mention_status,
        levels = c("Mentioned negative", "Not mentioned", "Mentioned positive")
      )
    ) %>%
    group_by(attribute, mention_status) %>%
    summarise(
      avg_rating = mean(rating),
      review_count = n(),
      .groups = "drop"
    )

  # Neutral reference: the subcategory's overall average rating
  subcategory_average = mean(
    review_df$rating[review_df$subcategory == subcategoryName]
  )

  mention_plot = ggplot(
    mention_data,
    aes(
      x = attribute,
      y = avg_rating,
      fill = mention_status
    )
  ) +
    geom_col(
      position = position_dodge(width = 0.8),
      width = 0.75
    ) +
    geom_text(
      aes(label = paste0(round(avg_rating, 2), "\n(n=", review_count, ")")),
      position = position_dodge(width = 0.8),
      vjust = 1.3,
      colour = "white",
      size = 2.8
    ) +
    geom_hline(
      aes(
        yintercept = subcategory_average,
        linetype = paste0("Subcategory average rating (", round(subcategory_average, 2), ")")
      ),
      colour = "grey20",
      linewidth = 0.8
    ) +
    scale_fill_manual(
      values = c(
        "Mentioned negative" = "tomato",
        "Not mentioned" = "grey60",
        "Mentioned positive" = "steelblue"
      )
    ) +
    scale_linetype_manual(
      values = "dashed"
    ) +
    labs(
      title = paste("Average Rating When an Attribute Is Not Mentioned vs Mentioned:", subcategoryName),
      subtitle = "Not mentioning an attribute leaves the rating at the subcategory average (neutral); a negative mention costs about two stars",
      x = "Attribute",
      y = "Average Customer Rating",
      fill = "Attribute in review",
      linetype = NULL
    ) +
    theme_minimal() +
    theme(legend.position = "top")

  print(mention_plot)

  ggsave(
    filename = paste0("./output/graphs/bar_rating_by_mention_status_", subcategoryName, ".png"),
    plot = mention_plot,
    width = 12,
    height = 7,
    units = "in"
  )
}

bar_number_of_reviews_per_aspect = function(){
  # Total number of reviews
  total_reviews = nrow(review_df)
  
  # Calculate attribute frequency
  attribute_frequency = attribute_df %>%
    filter(attribute_count > 0) %>%
    group_by(attribute) %>%
    summarise(
      review_count = n_distinct(asin),
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
      hjust = -0.1,
      size = 3.5
    ) +
    coord_flip() +
    scale_y_continuous(
      limits = c(0, total_reviews * 1.15)
    ) +
    labs(
      title = "Number of Reviews Discussing Each Attribute",
      subtitle = paste("Total Reviews:", total_reviews),
      x = "Attribute",
      y = "Number of Reviews",
      caption = "Percentages represent the share of total reviews mentioning each attribute."
    ) +
    theme_minimal()
  
  print(bar_plot)
  
  ggsave("./output/graphs/bar_number_of_reviews_per_aspect.png")
}

bar_attribute_sentiment_summary = function(){
  # Prepare sentiment data
  sentiment_data = attribute_df %>%
    filter(
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
    ) %>%
    complete(
      attribute = names(attribute_set),
      sentiment_type = c("Positive", "Negative"),
      fill = list(review_count = 0)
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
        )
      ),
      hjust = ifelse(
        sentiment_data$avg_score > 0,
        -0.1,
        1.1
      ),
      size = 3.5
    ) +
    coord_flip() +
    scale_fill_manual(
      values = c(
        "Positive" = "steelblue",
        "Negative" = "tomato"
      )
    ) +
    scale_y_continuous(
      breaks = seq(-1, 1, 0.25),
      expand = expansion(mult = 0.15)
    ) +
    labs(
      title = "Positive and Negative Sentiment by Attribute",
      subtitle = "Average sentiment scores and number of reviews",
      x = "Attribute",
      y = "Average Sentiment Score",
      fill = "Sentiment",
      caption = "Attributes without bars have no detected non-neutral sentiment."
    ) +
    theme_minimal()
  
  # Display in RStudio Plots tab
  print(sentiment_plot)
  ggsave(
    "./output/graphs/bar_attribute_sentiment_summary.png",
    width = 12,
    height = 7,
    units = "in",
    )
}

box_attribute_sentiment_by_rating = function(){
  rating_sentiment_data = attribute_df %>%
    filter(
      attribute_count > 0,
      !is.na(attribute_score)
    ) %>%
    left_join(
      review_df %>%
        select(review_id, rating = user_rating),
      by = "review_id"
    ) %>%
    filter(!is.na(rating))
  
  rating_sentiment_plot = ggplot(
    rating_sentiment_data,
    aes(
      x = factor(rating),
      y = attribute_score
    )
  ) +
    geom_boxplot(
      fill = "steelblue",
      alpha = 0.7,
      na.rm = TRUE
    ) +
    facet_wrap(
      ~ attribute,
      ncol = 3
    ) +
    scale_y_continuous(
      limits = c(-1, 1),
      breaks = seq(-1, 1, 0.5)
    ) +
    labs(
      title = "Attribute Sentiment Across Customer Ratings",
      subtitle = "Distribution of attribute sentiment scores by star rating",
      x = "Customer Rating",
      y = "Attribute Sentiment Score"
    ) +
    theme_minimal()
  
  print(rating_sentiment_plot)
  
  ggsave(
    filename = "./output/graphs/box_attribute_sentiment_by_rating.png",
    plot = rating_sentiment_plot,
    width = 12,
    height = 9,
    units = "in"
  )
}

bar_attributes_discussed_per_review = function(){
  # Count attributes discussed in each review
  review_attribute_count = attribute_df %>%
    group_by(review_id) %>%
    summarise(
      attributes_discussed = sum(attribute_count > 0, na.rm = TRUE),
      .groups = "drop"
    )
  
  # Include all reviews, even those without attribute records
  review_attribute_count = review_df %>%
    select(review_id) %>%
    left_join(
      review_attribute_count,
      by = "review_id"
    ) %>%
    mutate(
      attributes_discussed = coalesce(attributes_discussed, 0L)
    )
  
  # Count reviews for each level of attribute coverage
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
      vjust = -0.5,
      size = 3.5
    ) +
    scale_y_continuous(
      expand = expansion(mult = c(0, 0.15))
    ) +
    labs(
      title = "Number of Attributes Discussed per Review",
      subtitle = paste(
        "Total Reviews:", nrow(review_df)
      ),
      x = "Number of Attributes Discussed",
      y = "Number of Reviews",
      caption = "Percentages represent the share of total reviews."
    ) +
    theme_minimal()
  
  print(coverage_plot)
  
  ggsave(
    filename = "./output/graphs/bar_attributes_discussed_per_review.png",
    plot = coverage_plot,
    width = 11,
    height = 7,
    units = "in",
  )
}

bar_attributes_discussed_vs_rating = function(){
  # Count attributes discussed in each review
  review_attribute_count = attribute_df %>%
    group_by(review_id) %>%
    summarise(
      attributes_discussed = sum(attribute_count > 0, na.rm = TRUE),
      .groups = "drop"
    )
  
  # Join attribute counts with customer ratings
  rating_coverage_data = review_attribute_count %>%
    left_join(
      review_df %>%
        select(review_id, rating=user_rating),
      by = "review_id"
    ) %>%
    filter(!is.na(rating))
  
  # Calculate average rating
  rating_coverage_summary = rating_coverage_data %>%
    group_by(attributes_discussed) %>%
    summarise(
      avg_rating = mean(rating),
      review_count = n(),
      .groups = "drop"
    )
  
  rating_coverage_plot = ggplot(
    rating_coverage_summary,
    aes(
      x = factor(attributes_discussed),
      y = avg_rating
    )
  ) +
    geom_col(
      fill = "steelblue",
      width = 0.7
    ) +
    geom_text(
      aes(
        label = paste0(
          round(avg_rating, 2),
          " (n=", review_count, ")"
        )
      ),
      vjust = -0.5,
      size = 3.5
    ) +
    scale_y_continuous(
      limits = c(0, 5.5),
      breaks = 0:5
    ) +
    labs(
      title = "Average Customer Rating by Number of Attributes Discussed",
      subtitle = "Relationship between attribute coverage and customer ratings",
      x = "Number of Attributes Discussed",
      y = "Average Customer Rating",
      caption = "n = Number of reviews in each group"
    ) +
    theme_minimal()
  
  print(rating_coverage_plot)
}

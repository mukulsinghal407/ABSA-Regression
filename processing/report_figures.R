# ==========================================
# Report Figures (final report)
#
# Regenerates every figure used in the final report from the v2 outputs only.
#   F1  rating distribution                  F6  rating mix by mean attribute score
#   F2  reviews per subcategory              F7  cables coefficients (95% CI)
#   F3  attributes discussed per review      F8  peripherals coefficients (95% CI)
#   F4  mean rating vs # attributes          F9  predictor correlation heatmaps
#   F5  mentions + % negative per attribute  F10 product score card example
#   D1  system architecture diagram          D2  workflow diagram
#
# Models for F7-F9 come from processing/subcategory_regression.R (sourced, so the
# top-2 selection and specification are identical to the reported R output).
# Output: ./output/graphs/report/*.png (300 dpi)
# ==========================================

library(dplyr)
library(tidyr)
library(ggplot2)
library(scales)
library(cowplot)

setwd("~/Downloads/NUS/Semester 1/Big Data/capstone project")

OUTPUT_DIR = "./output/graphs/report"
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)

SCORECARD_ASIN = "B07VTK654B"
TOP_ATTRIBUTES = 15

# Palette (validated reference palette, light mode)
COLOR_PRIMARY = "#2a78d6"
COLOR_NEGATIVE = "#e34948"
COLOR_MUTED = "#a9a8a2"
COLOR_TEXT = "#0b0b0b"
COLOR_TEXT_SECONDARY = "#52514e"
COLOR_GRID = "#e6e5e0"
RATING_COLORS = c("1" = "#c23a39", "2" = "#f0a09f", "3" = "#d6d5d0", "4" = "#86b6ef", "5" = "#1c5cab")

SOURCE_NOTE = "Source: Amazon Reviews 2023, Electronics sample (n = 30,740); pipeline v2 outputs."

theme_report = function() {
  theme_minimal(base_family = "Arial", base_size = 10) +
    theme(
      plot.title = element_text(face = "bold", size = 11, colour = COLOR_TEXT),
      plot.subtitle = element_text(size = 9, colour = COLOR_TEXT_SECONDARY),
      plot.caption = element_text(size = 7.5, colour = COLOR_TEXT_SECONDARY, hjust = 0),
      plot.caption.position = "plot",
      plot.title.position = "plot",
      axis.text = element_text(colour = COLOR_TEXT_SECONDARY),
      axis.title = element_text(colour = COLOR_TEXT_SECONDARY, size = 9),
      panel.grid.major = element_line(colour = COLOR_GRID, linewidth = 0.3),
      panel.grid.minor = element_blank(),
      strip.text = element_text(face = "bold", colour = COLOR_TEXT, hjust = 0),
      legend.position = "top",
      legend.justification = "left",
      legend.title = element_text(size = 9, colour = COLOR_TEXT_SECONDARY),
      legend.text = element_text(size = 8.5, colour = COLOR_TEXT_SECONDARY)
    )
}

save_figure = function(plot, file_name, width = 6.5, height = 3.6) {
  ggsave(
    file.path(OUTPUT_DIR, file_name), plot,
    width = width, height = height, dpi = 300, device = ragg::agg_png, bg = "white"
  )
}

# ------------------------------------------
# Data
# ------------------------------------------
review_df = read.csv("./datasets/final_reviews.csv") %>%
  mutate(review_id = row_number())
attribute_df = read.csv("./output/attribute_df_v2.csv")
product_attribute_df = read.csv("./output/product_attribute_df_v2.csv")
attribute_set = read.csv("./datasets/final_attributes.csv")

mentions = attribute_df %>%
  filter(attribute_count > 0)

review_attribute_summary = review_df %>%
  select(review_id, rating) %>%
  left_join(
    mentions %>%
      group_by(review_id) %>%
      summarise(
        attributes_discussed = n(),
        mean_attribute_score = mean(attribute_score),
        .groups = "drop"
      ),
    by = "review_id"
  ) %>%
  mutate(attributes_discussed = coalesce(attributes_discussed, 0L))

# ------------------------------------------
# F1 Rating distribution
# ------------------------------------------
rating_counts = review_df %>%
  count(rating) %>%
  mutate(share = n / sum(n))

f1 = ggplot(rating_counts, aes(x = factor(rating), y = n)) +
  geom_col(fill = COLOR_PRIMARY, width = 0.7) +
  geom_text(
    aes(label = paste0(comma(n), "\n(", percent(share, accuracy = 0.1), ")")),
    vjust = -0.3, size = 3, colour = COLOR_TEXT_SECONDARY, lineheight = 0.9
  ) +
  scale_y_continuous(labels = comma, expand = expansion(mult = c(0, 0.18))) +
  labs(
    title = "Star ratings are heavily skewed towards five stars",
    x = "Star rating", y = "Number of reviews", caption = SOURCE_NOTE
  ) +
  theme_report() +
  theme(panel.grid.major.x = element_blank())
save_figure(f1, "F1_rating_distribution.png", height = 3.2)

# ------------------------------------------
# F2 Reviews per subcategory
# ------------------------------------------
subcategory_counts = review_df %>%
  count(subcategory) %>%
  mutate(highlight = subcategory %in% c("cables", "peripherals"))

f2 = ggplot(subcategory_counts, aes(x = n, y = reorder(subcategory, n), fill = highlight)) +
  geom_col(width = 0.72) +
  geom_text(aes(label = comma(n)), hjust = -0.15, size = 2.8, colour = COLOR_TEXT_SECONDARY) +
  scale_fill_manual(
    values = c(`TRUE` = COLOR_PRIMARY, `FALSE` = "#9ec5f4"),
    labels = c(`TRUE` = "Reported regression model", `FALSE` = "Other subcategory"),
    name = NULL
  ) +
  scale_x_continuous(labels = comma, expand = expansion(mult = c(0, 0.1))) +
  labs(
    title = "Reviews per product subcategory (22 subcategories)",
    x = "Number of reviews", y = NULL, caption = SOURCE_NOTE
  ) +
  theme_report() +
  theme(panel.grid.major.y = element_blank())
save_figure(f2, "F2_reviews_per_subcategory.png", height = 4.6)

# ------------------------------------------
# F3 Attributes discussed per review / F4 mean rating vs # attributes
# ------------------------------------------
attributes_per_review = review_attribute_summary %>%
  group_by(attributes_discussed) %>%
  summarise(reviews = n(), mean_rating = mean(rating), .groups = "drop") %>%
  mutate(share = reviews / sum(reviews))

f3 = ggplot(attributes_per_review, aes(x = factor(attributes_discussed), y = reviews)) +
  geom_col(fill = COLOR_PRIMARY, width = 0.7) +
  geom_text(
    aes(label = percent(share, accuracy = 0.1)),
    vjust = -0.4, size = 2.9, colour = COLOR_TEXT_SECONDARY
  ) +
  scale_y_continuous(labels = comma, expand = expansion(mult = c(0, 0.12))) +
  labs(
    title = "Number of distinct attributes detected per review",
    x = "Attributes discussed in the review", y = "Number of reviews", caption = SOURCE_NOTE
  ) +
  theme_report() +
  theme(panel.grid.major.x = element_blank())
save_figure(f3, "F3_attributes_per_review.png", height = 3.0)

f4 = ggplot(attributes_per_review, aes(x = attributes_discussed, y = mean_rating)) +
  geom_line(colour = COLOR_PRIMARY, linewidth = 0.7) +
  geom_point(colour = COLOR_PRIMARY, size = 2.6) +
  geom_text(
    aes(label = sprintf("%.2f", mean_rating)),
    vjust = -1.1, size = 2.9, colour = COLOR_TEXT_SECONDARY
  ) +
  geom_text(
    aes(y = 3.62, label = paste0("n=", comma(reviews))),
    size = 2.5, colour = COLOR_TEXT_SECONDARY
  ) +
  scale_x_continuous(breaks = 0:8) +
  scale_y_continuous(limits = c(3.55, 4.75), breaks = seq(3.6, 4.7, 0.2)) +
  labs(
    title = "Mean star rating falls as more attributes are discussed",
    x = "Attributes discussed in the review", y = "Mean star rating", caption = SOURCE_NOTE
  ) +
  theme_report()
save_figure(f4, "F4_rating_vs_attributes.png", height = 3.2)

# ------------------------------------------
# F5 Mentions and % negative per attribute (two panels, shared attribute order)
# ------------------------------------------
attribute_summary = mentions %>%
  group_by(attribute) %>%
  summarise(
    mentions = n(),
    mean_score = mean(attribute_score),
    negative_share = mean(attribute_score < 0),
    .groups = "drop"
  ) %>%
  arrange(desc(mentions)) %>%
  slice_head(n = TOP_ATTRIBUTES) %>%
  mutate(attribute = factor(attribute, levels = rev(attribute)))

f5_volume = ggplot(attribute_summary, aes(x = mentions, y = attribute)) +
  geom_col(fill = COLOR_PRIMARY, width = 0.7) +
  geom_text(aes(label = comma(mentions)), hjust = -0.15, size = 2.6, colour = COLOR_TEXT_SECONDARY) +
  scale_x_continuous(labels = comma, expand = expansion(mult = c(0, 0.18))) +
  labs(title = "Mentions (review × attribute)", x = NULL, y = NULL) +
  theme_report() +
  theme(panel.grid.major.y = element_blank(), plot.title = element_text(size = 9.5))

f5_negative = ggplot(attribute_summary, aes(x = negative_share, y = attribute)) +
  geom_col(fill = COLOR_NEGATIVE, width = 0.7) +
  geom_text(
    aes(label = percent(negative_share, accuracy = 1)),
    hjust = -0.15, size = 2.6, colour = COLOR_TEXT_SECONDARY
  ) +
  scale_x_continuous(labels = percent, limits = c(0, 0.75), expand = expansion(mult = c(0, 0))) +
  labs(title = "Share of mentions with negative score", x = NULL, y = NULL) +
  theme_report() +
  theme(
    panel.grid.major.y = element_blank(),
    axis.text.y = element_blank(),
    plot.title = element_text(size = 9.5)
  )

f5 = plot_grid(
  ggdraw() + draw_label(
    "Most-discussed attributes: volume and share of negative mentions",
    fontfamily = "Arial", fontface = "bold", size = 11, x = 0.01, hjust = 0
  ),
  plot_grid(f5_volume, f5_negative, rel_widths = c(1.25, 1)),
  ggdraw() + draw_label(
    paste("Top", TOP_ATTRIBUTES, "attributes by mentions.", SOURCE_NOTE),
    fontfamily = "Arial", size = 7.5, colour = COLOR_TEXT_SECONDARY, x = 0.01, hjust = 0
  ),
  ncol = 1, rel_heights = c(0.08, 1, 0.06)
)
save_figure(f5, "F5_attribute_volume_negative.png", height = 4.2)

# ------------------------------------------
# F6 Rating mix by review mean attribute score
# ------------------------------------------
rating_by_score_bin = review_attribute_summary %>%
  filter(!is.na(mean_attribute_score)) %>%
  mutate(
    score_bin = cut(
      mean_attribute_score,
      breaks = c(-1, -0.5, 0, 0.5, 1),
      include.lowest = TRUE,
      labels = c("Very negative\n[-1, -0.5]", "Mildly negative\n(-0.5, 0]",
                 "Mildly positive\n(0, 0.5]", "Very positive\n(0.5, 1]")
    )
  ) %>%
  count(score_bin, rating) %>%
  group_by(score_bin) %>%
  mutate(share = n / sum(n), reviews = sum(n)) %>%
  ungroup()

f6 = ggplot(rating_by_score_bin, aes(x = share, y = score_bin, fill = factor(rating))) +
  geom_col(width = 0.68, colour = "white", linewidth = 0.4, position = position_stack(reverse = TRUE)) +
  geom_text(
    aes(label = ifelse(share >= 0.06, percent(share, accuracy = 1), "")),
    position = position_stack(vjust = 0.5, reverse = TRUE),
    size = 2.7, colour = ifelse(rating_by_score_bin$rating %in% c(1, 5), "white", COLOR_TEXT)
  ) +
  scale_fill_manual(values = RATING_COLORS, name = "Star rating") +
  scale_x_continuous(labels = percent, expand = expansion(mult = c(0, 0.01))) +
  scale_y_discrete(labels = function(x) {
    counts = rating_by_score_bin %>% distinct(score_bin, reviews)
    paste0(x, "\nn=", comma(counts$reviews[match(x, counts$score_bin)]))
  }) +
  guides(fill = guide_legend(nrow = 1)) +
  labs(
    title = "Star-rating mix by the review's mean attribute sentiment score",
    x = "Share of reviews", y = NULL,
    caption = paste("Reviews with ≥ 1 detected attribute (n = 26,405).", SOURCE_NOTE)
  ) +
  theme_report() +
  theme(panel.grid.major.y = element_blank(), axis.text.y = element_text(lineheight = 0.9))
save_figure(f6, "F6_rating_mix_by_sentiment.png", height = 3.8)

# ------------------------------------------
# F7 / F8 Coefficient plots (top-2 subcategory regressions)
# ------------------------------------------
source("./processing/subcategory_regression.R")

coefficient_table = function(model) {
  coefficients = summary(model)$coefficients
  confidence = confint(model, level = 0.95)
  data.frame(
    term = rownames(coefficients),
    estimate = coefficients[, 1],
    p_value = coefficients[, 4],
    lower = confidence[, 1],
    upper = confidence[, 2]
  ) %>%
    filter(term != "(Intercept)") %>%
    mutate(
      attribute = sub("_attribute_(score|coverage)$", "", term),
      predictor = ifelse(grepl("_score$", term), "Sentiment score", "Coverage"),
      predictor = factor(predictor, levels = c("Sentiment score", "Coverage")),
      significant = ifelse(p_value < SIGNIFICANCE_LEVEL, "p < 0.05", "Not significant")
    )
}

coefficient_plot = function(model, subcategoryName, figure_label) {
  coefficients = coefficient_table(model)
  attribute_order = coefficients %>%
    filter(predictor == "Sentiment score") %>%
    arrange(estimate) %>%
    pull(attribute)
  coefficients = coefficients %>%
    mutate(attribute = factor(attribute, levels = attribute_order))

  model_summary = summary(model)
  ggplot(coefficients, aes(x = estimate, y = attribute, colour = significant)) +
    geom_vline(xintercept = 0, colour = COLOR_TEXT_SECONDARY, linewidth = 0.4) +
    geom_errorbar(aes(xmin = lower, xmax = upper), width = 0.25, linewidth = 0.6, orientation = "y") +
    geom_point(size = 2.4) +
    geom_text(
      aes(label = sprintf("%.2f", estimate)),
      vjust = -1.25, size = 2.4, show.legend = FALSE
    ) +
    facet_wrap(~predictor, nrow = 1) +
    scale_colour_manual(
      values = c("p < 0.05" = COLOR_PRIMARY, "Not significant" = COLOR_MUTED),
      name = NULL
    ) +
    labs(
      title = paste0(
        "Coefficients with 95% confidence intervals: ", subcategoryName,
        " (n = ", comma(nrow(model$model)), ", adj. R² = ",
        sprintf("%.3f", model_summary$adj.r.squared), ")"
      ),
      subtitle = "Dependent variable: star rating (1–5). OLS; unmentioned attribute → score 0, coverage 0.",
      x = "Change in star rating per unit of predictor", y = NULL,
      caption = SOURCE_NOTE
    ) +
    theme_report()
}

save_figure(coefficient_plot(models[["cables"]], "cables"), "F7_coefficients_cables.png", height = 3.6)
save_figure(coefficient_plot(models[["peripherals"]], "peripherals"), "F8_coefficients_peripherals.png", height = 3.6)

# ------------------------------------------
# F9 Correlation heatmaps of predictors
# ------------------------------------------
correlation_long = function(model, subcategoryName) {
  predictors = model$model %>% select(-rating)
  names(predictors) = names(predictors) %>%
    sub("_attribute_score$", " (S)", .) %>%
    sub("_attribute_coverage$", " (C)", .)
  correlation = cor(predictors)
  as.data.frame(as.table(correlation)) %>%
    rename(x = Var1, y = Var2, r = Freq) %>%
    mutate(subcategory = subcategoryName, x = factor(x, levels = colnames(correlation)),
           y = factor(y, levels = rev(colnames(correlation))))
}

heatmap_plot = function(model, subcategoryName) {
  correlation = correlation_long(model, subcategoryName)
  ggplot(correlation, aes(x = x, y = y, fill = r)) +
    geom_tile(colour = "white", linewidth = 0.3) +
    geom_text(aes(label = ifelse(x != y & abs(r) >= 0.4, sprintf("%.2f", r), "")),
              size = 1.9, colour = COLOR_TEXT) +
    scale_fill_gradient2(
      low = COLOR_NEGATIVE, mid = "#f0efec", high = COLOR_PRIMARY,
      midpoint = 0, limits = c(-1, 1), name = "Pearson r"
    ) +
    coord_fixed() +
    labs(title = subcategoryName, x = NULL, y = NULL) +
    theme_report() +
    theme(
      axis.text.x = element_text(angle = 60, hjust = 1, size = 6.2),
      axis.text.y = element_text(size = 6.2),
      panel.grid = element_blank(),
      legend.position = "none"
    )
}

f9_legend = get_legend(heatmap_plot(models[["cables"]], "cables") +
  theme(legend.position = "bottom", legend.key.width = unit(0.9, "cm"), legend.key.height = unit(0.25, "cm")))
f9 = plot_grid(
  ggdraw() + draw_label(
    "Pairwise correlation of the 14 predictors (S = sentiment score, C = coverage)",
    fontfamily = "Arial", fontface = "bold", size = 11, x = 0.01, hjust = 0
  ),
  plot_grid(
    heatmap_plot(models[["cables"]], "cables (max |r| = 0.53)"),
    heatmap_plot(models[["peripherals"]], "peripherals (max |r| = 0.68)")
  ),
  f9_legend,
  ggdraw() + draw_label(
    paste("Values shown where |r| ≥ 0.40; all |r| < 0.70.", SOURCE_NOTE),
    fontfamily = "Arial", size = 7.5, colour = COLOR_TEXT_SECONDARY, x = 0.01, hjust = 0
  ),
  ncol = 1, rel_heights = c(0.07, 1, 0.08, 0.05)
)
save_figure(f9, "F9_correlation_heatmaps.png", height = 4.4)

# ------------------------------------------
# F10 Product score card example
# ------------------------------------------
scorecard = product_attribute_df %>%
  filter(product_asin == SCORECARD_ASIN, total_attribute_reviews > 0) %>%
  mutate(attribute = reorder(attribute, total_attribute_reviews))

scorecard_long = scorecard %>%
  select(attribute, positive_reviews, negative_reviews) %>%
  pivot_longer(c(positive_reviews, negative_reviews), names_to = "polarity", values_to = "reviews") %>%
  mutate(polarity = factor(
    ifelse(polarity == "positive_reviews", "Positive", "Negative"),
    levels = c("Negative", "Positive")
  ))

f10 = ggplot(scorecard_long, aes(x = reviews, y = attribute, fill = polarity)) +
  geom_col(width = 0.68, colour = "white", linewidth = 0.4) +
  geom_text(
    aes(label = ifelse(reviews > 1, reviews, "")),
    position = position_stack(vjust = 0.5), size = 2.8, colour = "white"
  ) +
  geom_text(
    data = scorecard,
    aes(x = total_attribute_reviews, y = attribute,
        label = sprintf("mean %+.2f", sentiment)),
    inherit.aes = FALSE, hjust = -0.12, size = 2.7, colour = COLOR_TEXT_SECONDARY
  ) +
  scale_fill_manual(values = c(Positive = COLOR_PRIMARY, Negative = COLOR_NEGATIVE), name = NULL) +
  scale_x_continuous(expand = expansion(mult = c(0, 0.22))) +
  guides(fill = guide_legend(reverse = TRUE)) +
  labs(
    title = paste0("Product score card: security camera ", SCORECARD_ASIN,
                   " (", unique(scorecard$total_product_reviews), " reviews in sample)"),
    subtitle = "Reviews mentioning each attribute, split by sentiment; label = mean attribute sentiment score",
    x = "Reviews mentioning the attribute", y = NULL,
    caption = "Source: product_attribute_df_v2.csv (project pipeline v2)."
  ) +
  theme_report() +
  theme(panel.grid.major.y = element_blank())
save_figure(f10, "F10_product_scorecard.png", height = 3.4)

# ------------------------------------------
# D1 / D2 Diagrams (drawn with ggplot primitives)
# ------------------------------------------
draw_boxes = function(boxes, arrows, title, caption, xlim, ylim) {
  ggplot() +
    geom_segment(
      data = arrows, aes(x = x, y = y, xend = xend, yend = yend),
      arrow = arrow(length = unit(0.13, "cm"), type = "closed"),
      colour = COLOR_TEXT_SECONDARY, linewidth = 0.4
    ) +
    geom_rect(
      data = boxes, aes(xmin = x - w / 2, xmax = x + w / 2, ymin = y - h / 2, ymax = y + h / 2, fill = layer),
      colour = "white", linewidth = 0.6
    ) +
    geom_text(data = boxes, aes(x = x, y = y, label = label), size = 2.2,
              family = "Arial", lineheight = 0.92, colour = COLOR_TEXT) +
    scale_fill_manual(breaks = c("Input", "R processing", "Python (reticulate)", "Output", "Analysis"), values = c(
      "Input" = "#e6e5e0", "R processing" = "#cde2fb", "Python (reticulate)" = "#fbd3c3",
      "Output" = "#c9ecdf", "Analysis" = "#9ec5f4"
    ), name = NULL) +
    coord_cartesian(xlim = xlim, ylim = ylim, expand = FALSE) +
    labs(title = title, caption = caption) +
    theme_void(base_family = "Arial") +
    theme(
      plot.title = element_text(face = "bold", size = 11, colour = COLOR_TEXT),
      plot.caption = element_text(size = 7.5, colour = COLOR_TEXT_SECONDARY, hjust = 0),
      legend.position = "top", legend.justification = "left",
      legend.text = element_text(size = 8, colour = COLOR_TEXT_SECONDARY),
      plot.margin = margin(6, 6, 6, 6)
    )
}

architecture_boxes = tribble(
  ~x, ~y, ~w, ~h, ~layer, ~label,
  1.1, 6.0, 2.0, 0.8, "Input", "final_reviews.csv\n30,740 reviews",
  1.1, 4.8, 2.0, 0.8, "Input", "final_attributes.csv\n22 subcategories,\n60 attributes",
  1.1, 3.6, 2.0, 0.8, "Input", "fastText cc.en.300.bin\n300-d word vectors",
  1.1, 2.4, 2.0, 0.8, "Input", "DeBERTa-v3 ABSA\nsy12ssss/absa-deberta-v3",
  3.6, 6.0, 2.3, 0.8, "R processing", "Ingestion & preparation\nUTF-8 fix, title+text, sentence split\n(dplyr, tokenizers)",
  3.6, 4.8, 2.3, 0.8, "R processing", "Embedding cache\nnormalised vectors +\ntop-70 neighbours, sim ≥ 0.59\n(fastTextR, saveRDS)",
  6.2, 6.0, 2.3, 0.8, "R processing", "Context window\nprev + current + next sentence",
  6.2, 4.8, 2.3, 0.8, "R processing", "Aspect detection (per subcategory)\nlexical n-gram match ∪ semantic\ncosine ≥ 0.30, margin ≥ 0.05",
  6.2, 3.3, 2.3, 0.8, "Python (reticulate)", "Aspect sentiment inference\n[aspect] + [window], ≤ 256 tokens\nscore = P(pos) − P(neg)",
  8.8, 6.0, 2.3, 0.8, "Output", "Sentence table\nreview_sentence_aspect_v2.csv",
  8.8, 4.8, 2.3, 0.8, "Output", "Review × attribute table\nattribute_df_v2.csv",
  8.8, 3.6, 2.3, 0.8, "Output", "Product × attribute score card\nproduct_attribute_df_v2.csv",
  8.8, 2.4, 2.3, 0.8, "Analysis", "Subcategory OLS + correlation\n(lm) and figures (ggplot2)"
)

architecture_arrows = tribble(
  ~x, ~y, ~xend, ~yend,
  2.1, 6.0, 2.45, 6.0,
  2.1, 4.8, 2.45, 4.8,
  2.1, 3.6, 2.45, 4.65,
  4.75, 6.0, 5.05, 6.0,
  4.75, 4.8, 5.05, 4.8,
  6.2, 5.6, 6.2, 5.2,
  6.2, 4.4, 6.2, 3.7,
  2.1, 2.4, 5.05, 3.15,
  7.35, 3.4, 7.65, 5.85,
  8.8, 5.6, 8.8, 5.2,
  8.8, 4.4, 8.8, 4.0,
  8.8, 3.2, 8.8, 2.8
)

d1 = draw_boxes(
  architecture_boxes, architecture_arrows,
  "System architecture: R pipeline with a pretrained transformer called via reticulate",
  "Models are loaded once; dictionary embeddings are cached on disk; the transformer runs only on (sentence, detected aspect) pairs.",
  xlim = c(0, 10), ylim = c(1.8, 6.6)
)
save_figure(d1, "D1_system_architecture.png", height = 3.9)

workflow_boxes = tribble(
  ~x, ~y, ~w, ~h, ~layer, ~label,
  1.0, 2.0, 1.55, 1.0, "Input", "1. Load\nreviews +\ndictionary",
  2.75, 2.0, 1.55, 1.0, "R processing", "2. Prepare\ntitle + text,\nclean, split\n(84,342 sentences)",
  4.5, 2.0, 1.55, 1.0, "R processing", "3. Detect\naspects in\nsubcategory\n(lexical ∪ semantic)",
  6.25, 2.0, 1.55, 1.0, "Python (reticulate)", "4. Score\naspect sentiment\non 3-sentence\nwindow",
  8.0, 2.0, 1.55, 1.0, "R processing", "5. Aggregate\nreview × attribute:\nscore, count,\ncoverage",
  9.75, 2.6, 1.55, 0.8, "Output", "6a. Product\nscore card",
  9.75, 1.4, 1.55, 0.8, "Analysis", "6b. 22 OLS models\n→ select top 2\n→ correlation check"
)

workflow_arrows = tribble(
  ~x, ~y, ~xend, ~yend,
  1.78, 2.0, 1.97, 2.0,
  3.53, 2.0, 3.72, 2.0,
  5.28, 2.0, 5.47, 2.0,
  7.03, 2.0, 7.22, 2.0,
  8.78, 2.2, 8.97, 2.55,
  8.78, 1.8, 8.97, 1.45
)

d2 = draw_boxes(
  workflow_boxes, workflow_arrows,
  "Analytical workflow from raw reviews to manager-facing outputs",
  "Sentences with no detected aspect (27.2%) skip step 4.",
  xlim = c(0.1, 10.6), ylim = c(0.9, 3.1)
)
save_figure(d2, "D2_workflow.png", height = 2.6)

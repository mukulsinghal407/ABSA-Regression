# ==========================================
# ABSA Project - Main Execution
# ==========================================

setwd("~/Downloads/NUS/Semester 1/Big Data/capstone project") #Making sure we are in the right directory.
source("constants.R")
source("utils.R")
source("setup.R")
source("./models/bert_sentiments.R")
source("./processing/text_processing.R")
source("./processing/semantic_matching.R")
source("./processing/visualizations.R")
source("./processing/subcategory_regression.R")

STOP_WORDS = stopwords::stopwords("en")

version = 2
output_paths = c(
  attribute_df = paste0("./output/attribute_df_v", version, ".csv"),
  product_attribute_df = paste0("./output/product_attribute_df_v", version, ".csv"),
  review_sentence_aspect = paste0("./output/review_sentence_aspect_v", version, ".csv")
)

#Converting the amazon-reviews to an enriched version
review_df = get_formatted_review_df(reviews = reviews)

if (all(file.exists(output_paths))) {
  logger(paste("Loading existing version: ", version, "outputs; skipping ABSA pipeline"))
  attribute_df = read.csv(output_paths["attribute_df"])
  product_attribute_df = read.csv(output_paths["product_attribute_df"])
  review_sentence_aspect = read.csv(output_paths["review_sentence_aspect"])
} else {
  #Convert into sentence level data_set for aspect detection and sentiment analysis
  review_sentence_aspect = get_sentence_level_df(review_df = review_df)
  
  # Load fastText model once
  fasttext_model = load_fasttext_model(
    file_path = FASTTEXT_PATH
  )
  
  # Load existing dictionary embedding cache
  output = build_fasttext_cache(
    attribute_set = attribute_set,
    fasttext_model = fasttext_model
  )
  
  fasttext_cache = output$cache
  neighbour_aspect_mapping = output$neighbour_aspect_mapping
  rm(output)
  
  # Prepare subcategory-specific caches once
  subcategory_caches = build_subcategory_caches(
    fasttext_cache = fasttext_cache
  )
  
  #Loading BERT Model - to optimize memory
  bert = load_deberta_model()
  
  # ==========================================
  # Sentence-Level Aspect Detection + Sentiment
  # ==========================================
  
  for (i in seq(nrow(review_sentence_aspect))) {
    
    # 1. Clean current sentence
    sentence = clean_text(
      review_sentence_aspect[i, "sentence"][[1]]
    )
    
    # 2. Create sliding context window
    start = max(1, i - 1)
    end = min(nrow(review_sentence_aspect), i + 1)
    
    previous_sentence = if (
      i != start &&
      review_sentence_aspect$review_id[i] ==
      review_sentence_aspect$review_id[start]
    ) {
      clean_text(review_sentence_aspect$sentence[start])
    } else {
      ""
    }
    
    next_sentence = if (
      i != end &&
      review_sentence_aspect$review_id[i] ==
      review_sentence_aspect$review_id[end]
    ) {
      clean_text(review_sentence_aspect$sentence[end])
    } else {
      ""
    }
    
    combined_sentence = paste(
      previous_sentence,
      sentence,
      next_sentence
    )
    
    # 3. Retrieve applicable subcategory cache
    subcategory = review_sentence_aspect$subcategory[i]
    
    subcategory_cache = subcategory_caches[[subcategory]]
    
    if (is.null(subcategory_cache)) {
      next
    }
    
    # 4. Find longest applicable dictionary phrase
    terms = c(
      subcategory_cache$dictionary$aspect,
      subcategory_cache$dictionary$aspect_term
    )
    
    max_n = max(
      lengths(strsplit(terms, " ", fixed = TRUE))
    )
    
    # 5. Generate sentence candidates once
    candidates = generate_sentence_ngrams(
      sentence = sentence,
      max_n = max_n
    )
    
    # 6. One-pass lexical detection
    lexical_aspects = detect_lexical_aspects(
      sentence_ngrams = candidates$ngrams,
      subcategory_cache = subcategory_cache
    )
    
    # 7. fastText semantic detection
      
    semantic_aspects = detect_using_fasttext(
      words = candidates$words,
      subcategory_cache = subcategory_cache,
      fasttext_model = fasttext_model,
      min_similarity = 0.30,
      min_margin = 0.05
    )
    
    # 8. Combine unique detected aspects
    detected_aspects = unique(c(
      lexical_aspects,
      semantic_aspects
    ))
    
    # 9. DeBERTa sentiment inference
    for (aspect in detected_aspects) {
      
      review_sentence_aspect[i, aspect] = get_aspect_sentiment(
        sentence = combined_sentence,
        aspect = aspect,
        bert = bert
      )
    }
  }
  
  #Converting to a long form aspect level
  attribute_df = get_attribute_level_df()
  
  #====== 
  # ANALYSING INFORMATION FROM MANAGER POV
  #======
  
  product_attribute_df = attribute_df %>%
    group_by(asin,subcategory,attribute) %>%
    summarise(
      sentiment = ifelse(all(is.na(attribute_score)),NA,mean(attribute_score, na.rm = TRUE)),
        positive_reviews = sum(
          attribute_score > 0,
          na.rm = TRUE),
        neutral_reviews = sum(
          attribute_score == 0,
          na.rm = TRUE),
        negative_reviews = sum(
          attribute_score < 0,
          na.rm = TRUE),
        total_product_reviews = n_distinct(review_id),
        total_attribute_reviews = sum(positive_reviews,neutral_reviews,negative_reviews),
        .groups = "drop"
      ) %>%
    rename(
      product_asin = asin
      ) %>%
    relocate(
      total_product_reviews, .before = subcategory
    ) %>%
    relocate(
      total_attribute_reviews, .before = positive_reviews
    )
  
  write.csv(product_attribute_df,output_paths["product_attribute_df"], row.names = FALSE)
  write.csv(attribute_df,output_paths["attribute_df"], row.names = FALSE)
  write.csv(review_sentence_aspect,output_paths["review_sentence_aspect"], row.names = FALSE)
}

logger("Subcategory regression started")
models = run_subcategory_regression(attribute_df, review_df)

logger("Visualisations started")
bar_number_of_reviews_per_aspect("protection")
bar_attribute_sentiment_summary("protection")
bar_attributes_discussed_per_review("protection")
bar_attributes_discussed_vs_rating("protection")
bar_distinct_products_per_subcategory("protection")
bar_rating_by_mention_status("protection")


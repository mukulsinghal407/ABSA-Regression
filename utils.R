logger = function(text,level="INFO"){
  cat(
    paste("[ ",level," ]",now()," ",text,"\n"),
    file = "./output/log_dump.txt",
    append=TRUE
  )
}

get_attribute_dictionary = function(attribute_set){
  attribute_set = attribute_set %>%
    filter(
      !is.na(attribute),
      !is.na(aspect_term),
      trimws(attribute) != "",
      trimws(aspect_term) != ""
    )
  
  attribute_set = unique(attribute_set)
  
  attribute_dictionary = split(
    tolower(attribute_set$aspect_term),
    tolower(attribute_set$attribute)
  )
}

get_formatted_review_df = function(reviews){
  dataset = reviews %>%
    mutate(review_id = row_number()) %>%
    relocate(review_id)
  
  dataset = dataset %>%
    mutate(
      total_sentence_count = sapply(
        iconv(
          paste(coalesce(title, ""), coalesce(text, "")),
          from = "UTF-8",
          to = "UTF-8",
          sub = ""
        ),
        function(x) length(split_review_sentences(x))
      )
    )
  return(dataset)
}

get_sentence_level_df = function(review_df){
  dataset = review_df %>%
    select(review_id, asin, title,text,subcategory) %>%
    mutate(
      sentence = lapply(iconv(
        paste(coalesce(title, ""), coalesce(text, "")),
        from = "UTF-8",
        to = "UTF-8",
        sub = ""
      ), split_review_sentences)
    ) %>%
    tidyr::unnest_longer(sentence) %>%
    select(review_id, subcategory, asin, sentence)
  
  dataset[unique(attribute_set$aspect)] = NA
  return(dataset)
}

get_attribute_level_df = function(df){
  
  relevant_attributes = attribute_set %>%
    select(subcategory, attribute = aspect) %>%
    distinct()
  
  dataset = review_sentence_aspect %>%
    pivot_longer(
      cols = all_of(unique(attribute_set$aspect)),
      names_to = "attribute",
      values_to = "sentiment_score"
    ) %>%
    inner_join(
      relevant_attributes,
      by = c("subcategory", "attribute")
    ) %>%
    group_by(review_id, asin, subcategory, attribute) %>%
    summarise(
      attribute_score = if (all(is.na(sentiment_score))) {
        NA
      } else {
        round(mean(sentiment_score, na.rm = TRUE), 4)
      },
      attribute_count = sum(!is.na(sentiment_score)),
      .groups = "drop"
    ) %>%
    left_join(
      review_df %>%
        select(review_id, total_sentence_count),
      by = "review_id"
    ) %>%
    mutate(
      attribute_coverage = ifelse(
        total_sentence_count > 0,
        attribute_count / total_sentence_count,
        NA_real_
      )
    ) 
  
  return(
    dataset %>%
           select(
             review_id,
             asin,
             subcategory,
             attribute,
             attribute_score,
             attribute_count,
             attribute_coverage
           )
    )
}

clean_text = function(text) {
  text = gsub("<[^>]+>", " ", text)   # Remove HTML tags
  text = gsub("\\s+", " ", text)      # Remove extra whitespace
  text = trimws(text)                # Trim leading/trailing spaces
  return(text)
}

get_attributeMap_from_subcategory = function(subcategoryName){
  subcategory_set = attribute_set %>%
    filter(subcategory == subcategoryName) %>%
    select(attribute = aspect,aspect_term)
  
  return(get_attribute_dictionary(subcategory_set))
}

# ==========================================
# GloVe Competitive Attribute Matching
# ==========================================

cosine_similarity = function(vector1, vector2) {
  
  denominator = sqrt(sum(vector1^2)) *
    sqrt(sum(vector2^2))
  
  if (denominator == 0) {
    return(NA)
  }
  
  return(sum(vector1 * vector2) / denominator)
}

# Convert a word or phrase into an embedding
get_phrase_vector = function(phrase,glove_vectors) {
  
  words = unlist(
    strsplit(
      tolower(phrase),
      "[^[:alnum:]']+"
    )
  )
  
  words = words[nzchar(words)]
  
  # Keep words available in GloVe
  words = words[
    words %in% rownames(glove_vectors)
  ]
  
  if (length(words) == 0) {
    return(NULL)
  }
  
  # Retrieve all available word vectors
  vectors = glove_vectors[
    words,
    ,
    drop = FALSE
  ]
  
  # Average vectors across words
  phrase_vector = colMeans(vectors)
  
  return(as.numeric(phrase_vector))
}

# Compare a candidate against all attributes
match_glove_attribute = function(candidate,attribute_set,glove_vectors) {
  
  candidate_vector = get_phrase_vector(
    candidate,
    glove_vectors
  )
  
  if (is.null(candidate_vector)) {
    stop("Candidate has no available GloVe vectors.")
  }
  
  results = data.frame(
    attribute = character(),
    similarity = numeric()
  )
  
  for (attribute in names(attribute_set)) {
    
    terms = unique(c(
      attribute,
      attribute_set[[attribute]]
    ))
    
    scores = numeric()
    
    for (term in terms) {
      
      term_vector = get_phrase_vector(
        term,
        glove_vectors
      )
      
      if (!is.null(term_vector)) {
        
        similarity = cosine_similarity(
          candidate_vector,
          term_vector
        )
        
        scores = c(scores, similarity)
      }
    }
    
    if (length(scores) > 0) {
      
      results = rbind(
        results,
        data.frame(
          attribute = attribute,
          similarity = max(scores, na.rm = TRUE)
        )
      )
    }
  }
  
  results = arrange(results, desc(results$similarity))
  
  rownames(results) = NULL
  
  if(nrow(results)>1){
    return(results$attribute[1])
  }
  
  return(NA)
}

get_word_vector = function(word, glove_vectors) {
  
  word = tolower(trimws(word))
  
  if (!word %in% rownames(glove_vectors)) {
    return(NULL)
  }
  
  return(
    as.numeric(glove_vectors[word, ])
  )
}


#===================
# OVERALL SENTIMENT EXTRACTOR
#===================

get_overall_sentiment_score = function(sentiment){
  positive_score = 0L
  negative_score = 0L
  neutral_score = 0L
  
  for(i in seq(3)){
    if(result[i][[1]]$label == 'positive'){
      positive_score = result[i][[1]]$score
    }else if(result[i][[1]]$label == 'negative'){
      negative_score = result[i][[1]]$score
    }
  }
  
  if(positive_score - negative_score == 0L){
    return(round(neutral_score,4))
  }
  
  return(round(positive_score - negative_score,4))
}

convert_df_to_list = function(df, aspectName) {
  
  df$term = tolower(df$term)
  
  df$term = gsub(
    "[^[:alnum:]']+",
    " ",
    df$term
  )
  
  df$term = trimws(df$term)
  
  return(
    df %>%
      group_by(term) %>%
      summarise(
        similarity = max(similarity),
        .groups = "drop"
      ) %>%
      filter(similarity >= 0.59) %>%
      transmute(
        aspect = aspectName,
        term = term
      )
  )
}

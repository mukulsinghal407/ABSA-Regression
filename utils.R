


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

get_concised_dataset = function(
    df,other_info){
  
  final_df = df %>%
  group_by(parent_asin) %>%
  summarise(
    review_text = paste(sentence, collapse = " "),
    across(
      all_of(names(attribute_set)),
      list(
        score = ~round(
          ifelse(
            all(is.na(.x)),
            NA,
            mean(.x, na.rm = TRUE)
          ),
          2
        ),
        count = ~sum(!is.na(.x))
      ),
      .names = "{.col}_{.fn}"
    ),
    total_sentence_count = n()
  )
  return(merge(x=final_df, y=other_info, by.x="parent_asin", by.y="parent_asin",all=TRUE))
}


# ==========================================
# GloVe Competitive Attribute Matching
# ==========================================

cosine_similarity = function(vector1, vector2) {
  
  denominator = sqrt(sum(vector1^2)) *
    sqrt(sum(vector2^2))
  
  if (denominator == 0) {
    return(NA_real_)
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
# ==========================================
# Review to Sentence Split
# ==========================================
split_review_sentences = function(review) {
  
  if (length(review) != 1 ||
      is.na(review) ||
      !nzchar(trimws(review))) {
    return(character(0))
  }
  
  sentences = tokenizers::tokenize_sentences(review)[[1]]
  
  sentences = trimws(sentences)
  
  sentences = sentences[nzchar(sentences)]
  
  return(sentences)
}

# ==========================================
# Generate Sentence N-grams
# ==========================================
generate_sentence_ngrams = function(
    sentence,
    max_n = 3
) {
  
  words = strsplit(
    tolower(sentence),
    "[^[:alnum:]']+"
  )[[1]]
  
  words = words[nzchar(words)]
  
  stop_words = STOP_WORDS
  
  if (length(words) == 0) {
    return(list(
      words = character(0),
      ngrams = character(0)
    ))
  }
  
  ngrams = character()
  
  for (n in seq_len(min(max_n, length(words)))) {
    
    for (i in seq_len(length(words) - n + 1)) {
      
      phrase = paste(
        words[i:(i + n - 1)],
        collapse = " "
      )
      
      # Remove stopword unigrams only
      if (n == 1 && phrase %in% stop_words) {
        next
      }
      
      ngrams = c(ngrams, phrase)
    }
  }
  
  # Remove stopwords from individual words
  words = words[!words %in% stop_words]
  
  return(list(
    words = unique(words),
    ngrams = unique(ngrams)
  ))
}

# ==========================================
# One-Pass Lexical Aspect Detection
# ==========================================
detect_lexical_aspects = function(
    sentence_ngrams,
    subcategory_cache
) {
  
  dictionary = subcategory_cache$dictionary
  
  matched_aspects = dictionary$aspect[
    dictionary$aspect_term %in% sentence_ngrams
  ]
  
  # Also check canonical aspect names
  aspects = unique(dictionary$aspect)
  
  matched_aspects = c(
    matched_aspects,
    aspects[aspects %in% sentence_ngrams]
  )
  
  return(unique(matched_aspects))
}

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
# Lexical Aspect Detection
# ==========================================

detect_aspect_in_sentence = function(
  sentence,
  aspect_terms
){
  # Tokenize sentence
  words = strsplit(tolower(sentence), "[^[:alnum:]]+")[[1]]
  words = words[nzchar(trimws(words))]
  
  # Generate n-grams up to the longest dictionary phrase

  max_n = max(sapply(
    aspect_terms,
    function(term) {
      length(strsplit(term, " ")[[1]])
    }
  ))
  
  sentence_ngrams = character()
  
  for (n in seq(max_n)) {
    if (length(words) < n) {
      next
    }
    for (i in seq(length(words) - n + 1)) {
      phrase = paste(
        words[i:(i + n - 1)],
        collapse = " "
      )
      sentence_ngrams = c(sentence_ngrams, phrase)
    }
  }
  
  # Match n-grams against dictionary terms
  matches = aspect_terms %in% sentence_ngrams
  
  # Return TRUE or FALSE
  return(any(matches));
}


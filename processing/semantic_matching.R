# ==========================================
# fastText Semantic Matching
# ==========================================

load_fasttext_model = function(file_path) {
  
  if (!file.exists(file_path)) {
    stop("fastText model file not found: ", file_path)
  }
  
  model = fastTextR::ft_load(
    file = file_path
  )
  
  return(model)
}

build_fasttext_cache = function(
    attribute_set,
    fasttext_model,
    cache_path = FASTTEXT_CACHE_PATH,
    neighbour_path = FASTTEXT_NEIGHBOUR_PATH
) {
  
  dic_cache_found = FALSE
  nei_cache_found = FALSE
  
  # 1. Load existing cache
  if (file.exists(cache_path)) {
    logger("Loading existing fastText cache")
    dic_cache_found = TRUE
  }
  
  if(file.exists(neighbour_path)) {
    logger("Loading existing neighbour mapping cache")
    nei_cache_found = TRUE
  }
  
  if(dic_cache_found & nei_cache_found){
    return(
      list(
        cache = readRDS(cache_path),
        neighbour_aspect_mapping = readRDS(neighbour_path)
      )
    )
  }
  
  # 2. Get unique aspects and aspect terms
  terms = unique(c(
    attribute_set$aspect,
    attribute_set$aspect_term
  ))
  
  aspect_list = unique(trimws(unique(attribute_set$aspect)))
  
  neighbour_aspect_mapping = data.frame(
    aspect = character(),
    neighbour_terms = character()
  )
  
  if(!nei_cache_found){
    for(aspect in aspect_list){
    logger(sprintf("Extracting neighbour for: %s",aspect))
    output = fastTextR::ft_nearest_neighbors(fasttext_model,aspect,k=70L)
    neighbour_df = convert_df_to_list(
      data.frame(
        term = tolower(names(output)), 
        similarity = as.numeric(output)
        ),
      aspectName = aspect
      )
    
    neighbour_aspect_mapping = bind_rows(
      neighbour_aspect_mapping,
      neighbour_df %>%
        select(aspect, neighbour_terms = term)
    )
    }
  } else {
    neighbour_aspect_mapping = readRDS(neighbour_path)
  }
  
  terms = unique(c(
    terms,
    neighbour_aspect_mapping$neighbour_terms
  ))
  
  if(!dic_cache_found) {
  
  # 3. Generate 300d embeddings
  vectors = lapply(terms, function(term) {
    
    if (grepl(" ", term, fixed = TRUE)>1) {
      
      vector = fastTextR::ft_sentence_vectors(
        model = fasttext_model,
        sentences = term
      )
      
    } else {
      
      vector = fastTextR::ft_word_vectors(
        model = fasttext_model,
        words = term
      )
    }
    
    return(as.numeric(vector))
  })
  
  # 4. Create embedding matrix
  embedding_matrix = do.call(rbind, vectors)
  
  rownames(embedding_matrix) = terms
  
  # 5. Normalize embeddings
  norms = sqrt(rowSums(embedding_matrix^2))
  
  if (any(!is.finite(norms) | norms == 0)) {
    stop("Invalid fastText embedding vectors.")
  }
  
  embedding_matrix = embedding_matrix / norms
  
  # 6. Create cache object
  fasttext_cache = list(
    dictionary = attribute_set,
    vectors = embedding_matrix
  )
  
  # 7. Save cache to disk
  
    saveRDS(
      fasttext_cache,
      file = cache_path
    )
  }
  
  if(!nei_cache_found){
    saveRDS(
      neighbour_aspect_mapping,
      file = neighbour_path
    )
  }
  
  logger("Caches saved") #change this to logger
  
  return(
    list(
      cache = fasttext_cache,
      neighbour_aspect_mapping = neighbour_aspect_mapping
    )
  ) 
}

get_subcategory_vectors = function(
    subcategoryName,
    fasttext_cache
) {
  
  # Get dictionary terms relevant to this subcategory
  dictionary = fasttext_cache$dictionary %>%
    filter(subcategory == subcategoryName)
  
  # Include canonical aspect names and aspect terms
  terms = unique(c(
    dictionary$aspect,
    dictionary$aspect_term,
    neighbour_aspect_mapping$neighbour_terms[
      neighbour_aspect_mapping$aspect %in% dictionary$aspect
    ]
  ))
  
  # Retrieve pre-loaded vectors
  vectors = fasttext_cache$vectors[
    terms,
    ,
    drop = FALSE
  ]
  
  return(list(
    dictionary = dictionary,
    vectors = vectors
  ))
}

get_fasttext_similarities = function(
    candidate,
    fasttext_model,
    subcategory_cache
) {
  
  # Get embedding for a word or phrase
  if (grepl(" ", candidate, fixed = TRUE)) {
    
    candidate_vector = fastTextR::ft_sentence_vectors(
      model = fasttext_model,
      sentences = candidate
    )
    
  } else {
    
    candidate_vector = fastTextR::ft_word_vectors(
      model = fasttext_model,
      words = candidate
    )
  }
  
  candidate_vector = as.numeric(candidate_vector)
  
  # Normalize candidate embedding
  norm = sqrt(sum(candidate_vector^2))
  
  if (!is.finite(norm) || norm == 0) {
    return(NULL)
  }
  
  candidate_vector = candidate_vector / norm
  
  # Compare against cached dictionary vectors
  similarities = as.numeric(
    subcategory_cache$vectors %*% candidate_vector
  )
  
  return(data.frame(
    candidate = candidate,
    term = rownames(subcategory_cache$vectors),
    similarity = similarities
  ))
}

generate_candidate_ngrams = function(
    sentence,
    max_n = 2
) {
  
  words = strsplit(
    tolower(sentence),
    "[^[:alnum:]']+"
  )[[1]]
  
  words = words[nzchar(words)]
  
  candidates = character()
  
  for (n in seq_len(min(max_n, length(words)))) {
    
    for (i in seq_len(length(words) - n + 1)) {
      
      phrase = paste(
        words[i:(i + n - 1)],
        collapse = " "
      )
      
      candidates = c(candidates, phrase)
    }
  }
  
  return(unique(candidates))
}


# ==========================================
# Precompute Subcategory Caches
# ==========================================

build_subcategory_caches = function(fasttext_cache) {

  subcategories = unique(
    fasttext_cache$dictionary$subcategory
  )
  print(subcategories)
  
  subcategory_caches = lapply(
    subcategories,
    function(subcategory) {
      
      get_subcategory_vectors(
        subcategory = subcategory,
        fasttext_cache = fasttext_cache
      )
    }
  )
  
  names(subcategory_caches) = subcategories
  
  return(subcategory_caches)
}

# ==========================================
# fastText Semantic Aspect Detection
# ==========================================

detect_using_fasttext = function(
    words,
    subcategory_cache,
    fasttext_model,
    min_similarity = 0.30,
    min_margin = 0.10
) {
  
  # 1. Handle empty input
  if (length(words) == 0) {
    return(character(0))
  }
  
  words = unique(words)
  
  words = words[
    !words %in% FASTTEXT_IGNORE_WORDS
  ]
  
  if (length(words) == 0) {
    return(character(0))
  }
  
  dictionary = subcategory_cache$dictionary
  dictionary_vectors = subcategory_cache$vectors
  
  if (nrow(dictionary) == 0) {
    return(character(0))
  }
  
  # 2. Generate candidate word embeddings
  word_vectors = lapply(words, function(word) {
    
    vector = as.numeric(
      fastTextR::ft_word_vectors(
        model = fasttext_model,
        words = word
      )
    )
    
    return(vector)
  })
  
  word_matrix = do.call(rbind, word_vectors)
  
  rownames(word_matrix) = words
  
  # 3. Normalize word embeddings
  norms = sqrt(rowSums(word_matrix^2))
  
  valid = is.finite(norms) & norms > 0
  
  word_matrix = word_matrix[valid, , drop = FALSE]
  norms = norms[valid]
  
  if (nrow(word_matrix) == 0) {
    return(character(0))
  }
  
  word_matrix = word_matrix / norms
  
  # 4. Compare all words against cached dictionary vectors
  similarity_matrix = word_matrix %*% t(dictionary_vectors)
  
  # 5. Create term-to-attribute mapping
  neighbour_mapping = neighbour_aspect_mapping %>%
    filter(aspect %in% dictionary$aspect)
  
  mapping = bind_rows(
    dictionary %>%
      select(
        attribute = aspect,
        term = aspect_term
      ),
    
    data.frame(
      attribute = unique(dictionary$aspect),
      term = unique(dictionary$aspect)
    ),
    
    neighbour_mapping %>%
      select(
        attribute = aspect,
        term = neighbour_terms
      )
  )
  
  # 6. Calculate attribute scores per word
  detected_aspects = character()
  
  for (i in seq_len(nrow(similarity_matrix))) {
    
    similarities = similarity_matrix[i, ]
    
    attribute_scores = sapply(
      unique(mapping$attribute),
      function(aspect) {
        
        terms = mapping$term[
          mapping$attribute == aspect
        ]
        
        max(
          similarities[
            colnames(similarity_matrix) %in% terms
          ]
        )
      }
    )
    
    # Rank applicable attributes
    attribute_scores = sort(
      attribute_scores,
      decreasing = TRUE
    )
    
    if (length(attribute_scores) < 2) {
      next
    }
    
    best_similarity = attribute_scores[1]
    
    margin = attribute_scores[1] -
      attribute_scores[2]
    
    # 7. Apply confidence conditions
    if (
      best_similarity >= min_similarity &&
      margin >= min_margin
    ) {
      
      detected_aspects = c(
        detected_aspects,
        names(attribute_scores)[1]
      )
    }
  }
  
  # 8. Return unique canonical attributes
  return(unique(detected_aspects))
}

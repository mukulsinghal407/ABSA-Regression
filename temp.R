source("./processing/semantic_matching.R")

# ==========================================
# Load fastText Model
# ==========================================

fasttext_model = load_fasttext_model(
  file_path = FASTTEXT_PATH
)

battery_vector = fastTextR::ft_word_vectors(
  model = fasttext_model,
  words = "battery"
)

length(as.numeric(battery_vector))

charging_vector = fastTextR::ft_word_vectors(
  model = fasttext_model,
  words = "charging"
)

length(as.numeric(charging_vector))

fasttext_cache = build_fasttext_cache(
  attribute_set = attribute_set,
  fasttext_model = fasttext_model
)

# Check whether the file was saved
file.exists(FASTTEXT_CACHE_PATH)

# Check dimensions
dim(fasttext_cache$vectors)

# Check stored dictionary
head(fasttext_cache$dictionary)

# Verify normalization
sqrt(sum(fasttext_cache$vectors["battery", ]^2))


library(dplyr)
subcategory_cache = get_subcategory_vectors(
  subcategoryName = "displays",
  fasttext_cache = fasttext_cache
)

# Check relevant aspects
unique(subcategory_cache$dictionary$aspect)

# Check vector dimensions
dim(subcategory_cache$vectors)

# Check available terms
rownames(subcategory_cache$vectors)

results = get_fasttext_similarities(
  candidate = "brightness",
  fasttext_model = fasttext_model,
  subcategory_cache = subcategory_cache
)

results = results %>%
  arrange(desc(similarity))

head(results, 10)

attribute_scores = get_fasttext_attribute_scores(
  results = results,
  subcategory_cache = subcategory_cache
)

print(attribute_scores)

detected_aspect = get_best_fasttext_aspect(
  attribute_scores = attribute_scores,
  min_similarity = 0.30,
  min_margin = 0.01
)

print(detected_aspect)



sentence = "The screen brightness is excellent but the volume control is difficult."

candidates = generate_candidate_ngrams(
  sentence = sentence,
  max_n = 3
)

print(candidates)

results = lapply(candidates, function(candidate) {
  
  get_fasttext_similarities(
    candidate = candidate,
    fasttext_model = fasttext_model,
    subcategory_cache = subcategory_cache
  )
  
}) %>%
  dplyr::bind_rows()

print(results)

candidate_attribute_scores = results %>%
  split(.$candidate) %>%
  lapply(function(candidate_results) {
    
    scores = get_fasttext_attribute_scores(
      results = candidate_results,
      subcategory_cache = subcategory_cache
    )
    
    scores$candidate = candidate_results$candidate[1]
    
    return(scores)
  }) %>%
  dplyr::bind_rows()

print(candidate_attribute_scores)

detected_aspects = candidate_attribute_scores %>%
  split(.$candidate) %>%
  lapply(function(scores) {
    
    scores = scores %>%
      arrange(desc(similarity))
    
    get_best_fasttext_aspect(
      attribute_scores = scores,
      min_similarity = 0.30,
      min_margin = 0.10
    )
    
  }) %>%
  unlist(use.names = FALSE) %>%
  unique()

print(detected_aspects)

candidate_attribute_scores %>%
  group_by(candidate) %>%
  slice_max(similarity, n = 2) %>%
  arrange(candidate, desc(similarity))




sentence = "The screen brightness is excellent."

candidates = generate_sentence_ngrams(
  sentence = sentence,
  max_n = 3
)

print(candidates$words)

print(candidates$ngrams)


sentence = "The screen brightness is excellent."

candidates = generate_sentence_ngrams(
  sentence = sentence,
  max_n = 3
)

subcategory_cache = subcategory_caches[["displays"]]

lexical_aspects = detect_lexical_aspects(
  sentence_ngrams = candidates$ngrams,
  subcategory_cache = subcategory_cache
)

print(lexical_aspects)

sentence = "The screen brightness is good and the sound is excellent."

candidates = generate_sentence_ngrams(
  sentence = sentence,
  max_n = 3
)

lexical_aspects = detect_lexical_aspects(
  sentence_ngrams = candidates$ngrams,
  subcategory_cache = subcategory_caches[["displays"]]
)

print(lexical_aspects)

subcategory_caches[["displays"]]$dictionary %>%
  filter(aspect_term %in% candidates$ngrams | aspect %in% candidates$ngrams) %>%
  select(aspect, aspect_term)


sentence = "The screen brightness is excellent and the sound is great."

candidates = generate_sentence_ngrams(
  sentence = sentence,
  max_n = 3
)

detect_lexical_aspects(
  sentence_ngrams = candidates$ngrams,
  subcategory_cache = subcategory_caches[["displays"]]
)

"screen" %in% candidates$ngrams

subcategory_caches[["displays"]]$dictionary %>%
  filter(aspect == "display") %>%
  select(aspect_term)

subcategory_cache = subcategory_caches[["displays"]]

results = get_fasttext_similarities(
  candidate = "bright",
  fasttext_model = fasttext_model,
  subcategory_cache = subcategory_cache
)

attribute_scores = get_fasttext_attribute_scores(
  results = results,
  subcategory_cache = subcategory_cache
)

print(attribute_scores)

# -----

sentence = "The product arrived yesterday."

candidates = generate_sentence_ngrams(
  sentence = sentence,
  max_n = 3
)

subcategory_cache = subcategory_caches[["displays"]]

semantic_aspects = detect_using_fasttext(
  words = candidates$words,
  subcategory_cache = subcategory_cache,
  fasttext_model = fasttext_model,
  min_similarity = 0.4,
  min_margin = 0.05
)

print(semantic_aspects)

test_sentences = c(
  "The screen is bright and the sound is excellent.",
  "The screen looks blurry.",
  "The volume buttons are difficult to press.",
  "The product arrived yesterday.",
  "Excellent product, highly recommended."
)

start = Sys.time()
output = fastTextR::ft_nearest_neighbors(fasttext_model,"battery",k=70L)
Sys.time() - start
str(output)

fit_vector = as.numeric(
  fastTextR::ft_sentence_vectors(fasttext_model, "fit look")
)

punctuated_vector = as.numeric(
  fastTextR::ft_sentence_vectors(fasttext_model, "fit so")
)

cosine_similarity(
  fit_vector,
  punctuated_vector
)

fastTextR::ft_analogies(fasttext_model,c("fit",'look','fine'))

#-------------------
# PACKAGES AND MODULES
#-------------------
REQUIRED_PACKAGES = c("reticulate", "dplyr","tokenizers","lubridate","ggplot2","tidyverse","fastTextR","ggthemes") #R packages here.
REQUIRED_MODULES = c( "torch","numpy","sentence_transformers") #Python modules here.

#-------------------
# SELECTED PRE-TRAINED MODEL
#-------------------
DEBERTA_MODEL_ID = "sy12ssss/absa-deberta-v3"
# ROBERTA_MODEL_ID = "cardiffnlp/twitter-roberta-base-sentiment-latest"

GLOVE_PATH_300 = "./embeddings/glove.6B.300d.txt"

# ==========================================
# fastText Configuration
# ==========================================

FASTTEXT_PATH = "./embeddings/cc.en.300.bin"

FASTTEXT_CACHE_PATH = "./embeddings/fasttext_dictionary_cache.rds"
FASTTEXT_NEIGHBOUR_PATH = "./embeddings/fasttext_neightbour_mapping_cache.rds"

FASTTEXT_IGNORE_WORDS = c(
  "product", "item", "thing",
  "good", "great", "excellent", "nice",
  "bad", "terrible", "awful", "amazing",
  "works", "working", "job",
  "bought", "purchased", "buy",
  "ask", "recommend", "reasonable"
)

#-------------------
# FEATURE FLAGS
#-------------------
FEATURE_FLAGS = list(
  ENABLE_GLOVE_MATCHING = TRUE,
  ENABLE_REGRESSION = FALSE,
  ENABLE_VISUALISATION = FALSE
)

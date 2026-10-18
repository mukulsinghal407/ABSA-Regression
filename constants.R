#-------------------
# PACKAGES AND MODULES
#-------------------
REQUIRED_PACKAGES = c("reticulate", "dplyr","tokenizers")#,"sentimentr") #R packages here. ##fastTextR
REQUIRED_MODULES = c( "torch","numpy","sentence_transformers") #Python modules here.

#-------------------
# SELECTED PRE-TRAINED MODEL
#-------------------
DEBERTA_MODEL_ID = "sy12ssss/absa-deberta-v3"
ROBERTA_MODEL_ID = "cardiffnlp/twitter-roberta-base-sentiment-latest"

GLOVE_PATH_300 = "./embeddings/glove.6B.300d.txt"
GLOVE_PATH_200 = "./embeddings/glove.6B.200d.txt"
GLOVE_PATH_100 = "./embeddings/glove.6B.100d.txt"

#-------------------
# FEATURE FLAGS
#-------------------
FEATURE_FLAGS = list(
  ENABLE_OVERALL_SENTIMENT = FALSE,
  ENABLE_GLOVE_MATCHING = FALSE,
  ENABLE_REGRESSION = FALSE,
  ENABLE_VISUALISATION = FALSE
)

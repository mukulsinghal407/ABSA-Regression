source("./processing/text_processing.R")
detect_aspect_in_sentence(
  sentence="Even screwing the speaker in tightly, the stink still comes out the port.",
  aspect_terms = attribute_set$design
)

library(sentimentr)

review = "The battery is terrible but the camera is excellent."

result = sentimentr::sentiment_by(review)

print(result)

transformers = reticulate::import("transformers")

overall_model = transformers$pipeline(
  task = "sentiment-analysis",
  model = "cardiffnlp/twitter-roberta-base-sentiment-latest",
  device = -1L
)

review = "The battery is terrible. The camera is excellent. Overall I am disappointed"

result = overall_model(
  review,
  truncation = TRUE,
  max_length = 512L,
  top_k = NULL
)

result[3][[1]]$score - result[1][[1]]$score

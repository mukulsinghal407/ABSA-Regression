# ==========================================
# ABSA Project - Main Execution
# ==========================================
setwd("~/Downloads/NUS/Semester 1/Big Data/capstone project") #Making sure we are in the right directory.
source("constants.R")
source("utils.R")
source("setup.R")
source("./models/bert_sentiments.R")
source("./embeddings/glove_loader.R")
source("./processing/text_processing.R")

#Loading BERT Model
bert = load_deberta_model()

# glove_vectors = load_glove_model(
#   file_path = GLOVE_PATH_100
# )
# get_word_vector(word = "lens", glove_vectors = glove_vectors)


#--------------------
# The following is the flow of the implementation
# 1. Break review into sentences if the review is bigger than the threshold.
# 2. For every sentence perform aspect detection.
# 3. If the aspect is found using attributes.csv then perform aspect sentiment.
# 4. If the aspect is not found send it to GLOVE for implicit mention, if found do aspect sentiment.
# 5. Record the sentiment score along with parent_asin, helpful votes, rating.
#   Example entry ID, overall_sentiment_score, battery_sentiment_score, microphone_sentiment_score.
# 6.Run regression.
# 7.Do Data Visualization
#--------------------

review_sentence_aspect = reviews %>%
  select(parent_asin, text) %>%
  mutate(
    sentence = lapply(text, split_review_sentences)
    ) %>%
  tidyr::unnest_longer(sentence) %>%
  select(parent_asin, sentence)
review_sentence_aspect[names(attribute_set)] = NA

for(i in seq(nrow(review_sentence_aspect))){
  sentence = review_sentence_aspect[i,"sentence"]
  
  # Creating context window using sentence sliding window for aspect analysis
  start = max(1,i-1)
  end = min(nrow(review_sentence_aspect),i+1)
  
  start = ifelse(review_sentence_aspect[i,'parent_asin']==review_sentence_aspect[start,"parent_asin"] & i!=start, review_sentence_aspect[start,"sentence"], "")
  end = ifelse(review_sentence_aspect[i,'parent_asin']==review_sentence_aspect[end,"parent_asin"] & i!=end,review_sentence_aspect[end,"sentence"],"")
  combined_sentence = paste(start,sentence,end)
  #rm(start,end)
  
  for(aspect in names(attribute_set)){
    
    # 1. Detect using attribute_set (CSV only approach).
    aspect_found = detect_aspect_in_sentence(
      sentence = sentence, 
      aspect_terms = attribute_set[[aspect]]
    )
    print(paste("Lexical Match -- ",i,review_sentence_aspect[i,"parent_asin"],aspect,aspect_found))
    # 2. Detect using GLOVE if no match found in CSV.
    if(FEATURE_FLAGS$ENABLE_GLOVE_MATCHING & !aspect_found){
      aspect_found = detect_using_glove(
        sentence = sentence,
        aspect = aspect,
        glove_vectors = glove_vectors
      )
      print(paste("GLOVE Match -- ",i,review_sentence_aspect[i,"parent_asin"],aspect,aspect_found))
    }
    
    # 3. Doing sentiment analysis using BERT if aspect is found in either attribute.csv or GLOVE.
    if(aspect_found){
      print(sprintf("Extracting sentimenet for aspect: %s, review_id: %s, sentence_id: %0.f",aspect,review_sentence_aspect[i,"parent_asin"],i))
      review_sentence_aspect[i,aspect] = get_aspect_sentiment(
        sentence = combined_sentence,
        aspect = aspect,
        bert = bert
      )$sentiment_score
    }
  }
}

final_df = get_concised_dataset(
  df = review_sentence_aspect, 
  other_info = reviews %>% 
    select(c("parent_asin","helpful_vote","rating","metadata_average_rating")) #What all do we want to extract from the original df
)

#Add Regression Model Visualisation and all
if(FEATURE_FLAGS$ENABLE_REGRESSION){
  print("Regression Initialised")
}

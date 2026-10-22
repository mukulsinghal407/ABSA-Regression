logger = function(text,level="INFO"){
  cat(
    paste("[ ",level," ]",now()," ",text,"\n"),
    file = "./output/log_dump.txt",
    append=TRUE
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

get_attribute_level_df = function(){
  
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
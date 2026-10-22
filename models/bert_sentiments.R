# ------------------------------------------
# 1. Load pretrained Models
# ------------------------------------------
load_deberta_model = function() {
  
  transformers = reticulate::import("transformers")
  torch = reticulate::import("torch")
  
  tokenizer = transformers$AutoTokenizer$from_pretrained(
    DEBERTA_MODEL_ID,
    use_fast = TRUE
  )
  
  model = transformers$AutoModelForSequenceClassification$from_pretrained(
    DEBERTA_MODEL_ID
  )
  
  model$eval()
  
  return(list(
    tokenizer = tokenizer,
    model = model,
    torch = torch
  ))
}

# ------------------------------------------
# 2. Aspect sentiment classification
# ------------------------------------------
get_aspect_sentiment = function(
    sentence,
    aspect,
    bert
) {
  
  if (length(sentence) != 1 ||
      length(aspect) != 1 ||
      is.na(sentence) ||
      is.na(aspect) ||
      !nzchar(trimws(sentence)) ||
      !nzchar(trimws(aspect))) {
    
    stop("Sentence and aspect must be nonempty strings.")
  }
  
  # Tokenize using verified model input order
  inputs = bert$tokenizer(
    aspect,
    sentence,
    return_tensors = "pt",
    truncation = TRUE,
    max_length = 256L
  )
  
  # Run pretrained model
  # No training or gradient calculation
  with_no_grad = bert$torch$no_grad()
  
  with_no_grad$`__enter__`()
  
  outputs = tryCatch(
    {
      bert$model(
        input_ids = inputs$input_ids,
        attention_mask = inputs$attention_mask
      )
    },
    finally = {
      with_no_grad$`__exit__`(NULL, NULL, NULL)
    }
  )
  
  # Convert logits into probabilities
  probabilities = bert$torch$softmax(
    outputs$logits,
    dim = -1L
  )
  
  probabilities = reticulate::py_to_r(
    probabilities$detach()$cpu()$numpy()
  )
  
  # Verified label mapping:
  # 0 = negative
  # 1 = neutral
  # 2 = positive
  
  negative = probabilities[1, 1]
  neutral = probabilities[1, 2]
  positive = probabilities[1, 3]
  
  sentiment_score = positive - negative
  
  return(round(sentiment_score, 4))
}

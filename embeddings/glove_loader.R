# ==========================================
# Full Vocabulary GloVe 100d Loader
# ==========================================

load_glove_model = function(
    file_path,
    cache_path = "./embeddings/glove_100d.rds",
    dimensions = 100L
) {
  
  # Load cached model if available
  if (file.exists(cache_path)) {
    
    print("Loading cached GloVe model...")
    
    glove = readRDS(cache_path)
    
    return(glove)
  }
  
  print("Reading pretrained GloVe vectors...")
  
  # Read full GloVe text file
  glove_data = read.table(
    file_path,
    header = FALSE,
    quote = "",
    comment.char = "",
    fill = FALSE,
    stringsAsFactors = FALSE
  )
  
  # Extract vocabulary
  words = glove_data[[1]]
  
  # Convert embeddings to numeric matrix
  vectors = as.matrix(
    glove_data[, -1]
  )
  
  storage.mode(vectors) = "double"
  
  # Verify dimensions
  if (ncol(vectors) != dimensions) {
    stop("Incorrect GloVe dimensions.")
  }
  
  # Assign word names
  rownames(vectors) = words
  
  # Remove temporary objects
  rm(glove_data, words)
  
  gc()
  
  # Save for future sessions
  saveRDS(
    vectors,
    cache_path,
    compress = FALSE
  )
  
  print("GloVe model loaded successfully.")
  
  return(vectors)
}
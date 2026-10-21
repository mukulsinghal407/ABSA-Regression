# ==========================================
# ABSA Project - Environment Setup
# ==========================================

load_packages = function() {
  
  for (pkg in REQUIRED_PACKAGES) {
    
    if (!requireNamespace(pkg, quietly = TRUE)) {
      install.packages(pkg)
    }
    
    library(pkg, character.only = TRUE)
  }
  
  message("R packages loaded successfully.")
}

setup_python = function() {
  
  # Select the dedicated Python environment
  reticulate::use_virtualenv(
    "absa-env",
    required = TRUE
  )
  
  for (module in REQUIRED_MODULES) {
    
    if (!reticulate::py_module_available(module)) {
      stop(paste("Missing Python module:", module))
    }
  }
  
  message("Python environment configured successfully.")
}

load_packages()
setup_python()

# ==========================================
# Data Loader - Loading Required Data
# ==========================================
reviews = read.csv("./datasets/final_reviews.csv")
attribute_set = read.csv("./datasets/final_attributes.csv")

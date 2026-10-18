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
reviews = read.csv("./datasets/sample_test_data_set.csv")
attribute_set = read.csv("./datasets/attributes.csv")
attribute_set = get_attribute_dictionary(attribute_set) #Transforming from a long-form to a list.

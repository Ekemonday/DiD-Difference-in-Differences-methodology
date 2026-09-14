## run_pipeline.R
##
## Master script: runs the full SFPSP evaluation pipeline end-to-end, in order.
## Run this from the repository root:
##
##   Rscript run_pipeline.R
##
## First-time setup: install dependencies with
##
##   Rscript install_packages.R

stages <- c(
  "R/01_generate_synthetic_data.R",
  "R/02_clean_data.R",
  "R/03_descriptives.R",
  "R/04_did_analysis.R",
  "R/05_build_data_dictionary.R"
)

for (s in stages) {
  cat("\n", strrep("#", 70), "\n", sep = "")
  cat("# Running:", s, "\n")
  cat(strrep("#", 70), "\n\n")
  source(s)
}

cat("\nPipeline complete.\n")
cat("  Raw data:        data/raw/\n")
cat("  Cleaned data:     data/processed/\n")
cat("  Figures:          outputs/figures/\n")
cat("  Tables:           outputs/tables/\n")
cat("  Regression output: outputs/regression/\n")
cat("  Excel workbook:   outputs/Cleaned_Dataset_and_Data_Dictionary.xlsx\n")

## install_packages.R
##
## Installs all R packages required to run this project.
## Run once before the pipeline:
##
##   Rscript install_packages.R

required_packages <- c(
  "dplyr",
  "tidyr",
  "stringr",
  "ggplot2",
  "ggpubr",
  "scales",
  "sandwich",
  "lmtest",
  "openxlsx"
)

installed <- rownames(installed.packages())
to_install <- setdiff(required_packages, installed)

if (length(to_install) > 0) {
  cat("Installing:", paste(to_install, collapse = ", "), "\n")
  install.packages(to_install, repos = "https://cloud.r-project.org")
} else {
  cat("All required packages are already installed.\n")
}

cat("\nVerifying...\n")
for (p in required_packages) {
  ok <- requireNamespace(p, quietly = TRUE)
  cat(sprintf("  %-12s %s\n", p, ifelse(ok, "OK", "MISSING - install failed")))
}

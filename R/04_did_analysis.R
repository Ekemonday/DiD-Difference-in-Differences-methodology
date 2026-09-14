## 04_did_analysis.R
##
## Difference-in-Differences regression analysis.
## Uses lm() + sandwich/lmtest for cluster-robust standard errors (by state),
## the standard R equivalent of Stata's `reg ..., cluster(state)`.
##
## Outputs:
##   outputs/regression/did_results_summary.csv
##   outputs/regression/did_full_regression_output.txt
##
## Run from the repository root: Rscript R/04_did_analysis.R

suppressPackageStartupMessages({
  library(dplyr)
  library(sandwich)
  library(lmtest)
})

df <- read.csv("data/processed/cleaned_survey_data.csv", stringsAsFactors = FALSE)

df$education <- factor(df$education, levels = c("No Education", "Primary", "Secondary", "Higher", "Missing"))
df$wealth_valid <- ifelse(df$wealth_quintile == -1, NA, df$wealth_quintile)
df$state <- factor(df$state)

OUT <- "outputs/regression"
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

log_lines <- c()
logcat <- function(x) {
  txt <- paste(capture.output(print(x)), collapse = "\n")
  log_lines <<- c(log_lines, txt)
  cat(txt, "\n")
}

## Helper: fit OLS (linear probability model) with SEs clustered by state
cluster_lm <- function(formula, data) {
  m <- lm(formula, data = data)
  vc <- vcovCL(m, cluster = data$state, type = "HC1")
  list(model = m, vcov = vc, test = coeftest(m, vcov. = vc))
}

## ---------------- Model 1: Simple 2x2 DiD (no controls) ----------------
m1 <- cluster_lm(modern_contraceptive_use ~ treatment_group + post + treat_x_post, data = df)
logcat(strrep("=", 70))
logcat("MODEL 1: Simple DiD (linear probability model), clustered SE by state")
logcat(strrep("=", 70))
logcat(m1$test)

## ---------------- Model 2: DiD with covariates + state FE ----------------
## treatment_group dropped: perfectly collinear with state fixed effects,
## since each state is entirely treatment OR control.
df_cov <- df %>% filter(!is.na(wealth_valid))

m2 <- cluster_lm(
  modern_contraceptive_use ~ post + treat_x_post + age + education + wealth_valid +
    parity + urban_rural + currently_in_union + state,
  data = df_cov
)
logcat(paste0("\n", strrep("=", 70)))
logcat("MODEL 2: DiD with individual covariates + state fixed effects, clustered SE")
logcat("(treatment_group main effect dropped: collinear with state fixed effects)")
logcat(strrep("=", 70))
logcat(m2$test)

## ---------------- Model 3: Secondary outcome (any method) ----------------
m3 <- cluster_lm(
  any_contraceptive_use ~ post + treat_x_post + age + education + wealth_valid +
    parity + urban_rural + currently_in_union + state,
  data = df_cov
)
logcat(paste0("\n", strrep("=", 70)))
logcat("MODEL 3: DiD on secondary outcome (any contraceptive method)")
logcat(strrep("=", 70))
logcat(m3$test)

## ---------------- Robustness: baseline-only placebo check ----------------
## Only 2 waves are available, so a formal multi-period pre-trend/event-study
## test is not possible. As a proxy, we check whether treatment and control
## states already differed at baseline (should be small/insignificant).
baseline <- df %>% filter(wave_year == 2018)
m_baseline <- cluster_lm(modern_contraceptive_use ~ treatment_group, data = baseline)
logcat(paste0("\n", strrep("=", 70)))
logcat("ROBUSTNESS CHECK: Baseline (pre-programme) treatment vs control gap")
logcat("(Should be small/insignificant to support parallel-trends plausibility)")
logcat(strrep("=", 70))
logcat(m_baseline$test)

## ---------------- Save key coefficients ----------------
extract_did <- function(fit, label) {
  coef_tab <- fit$test
  coef_val <- coef_tab["treat_x_post", "Estimate"]
  se_val <- coef_tab["treat_x_post", "Std. Error"]
  p_val <- coef_tab["treat_x_post", "Pr(>|t|)"]
  ci <- coef_val + c(-1, 1) * qnorm(0.975) * se_val
  data.frame(
    model = label,
    did_coefficient_pp = round(coef_val * 100, 2),
    std_error_pp = round(se_val * 100, 2),
    p_value = signif(p_val, 4),
    ci_lower_pp = round(ci[1] * 100, 2),
    ci_upper_pp = round(ci[2] * 100, 2)
  )
}

summary_table <- bind_rows(
  extract_did(m1, "Model 1: Simple DiD (no controls)"),
  extract_did(m2, "Model 2: DiD + covariates + state FE (modern method)"),
  extract_did(m3, "Model 3: DiD + covariates + state FE (any method)")
)

cat("\n\n=== DiD COEFFICIENT SUMMARY (percentage points) ===\n")
print(summary_table)

write.csv(summary_table, file.path(OUT, "did_results_summary.csv"), row.names = FALSE)
writeLines(log_lines, file.path(OUT, "did_full_regression_output.txt"))

cat("\nSaved:", file.path(OUT, "did_results_summary.csv"), "and",
    file.path(OUT, "did_full_regression_output.txt"), "\n")

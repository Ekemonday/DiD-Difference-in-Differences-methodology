## 02_clean_data.R
##
## Cleaning pipeline for data/raw/raw_survey_data.csv.
## Each step is logged to data/processed/cleaning_log.txt so the process is
## fully auditable.
##
## Output: data/processed/cleaned_survey_data.csv, data/processed/cleaning_log.txt
##
## Run from the repository root: Rscript R/02_clean_data.R

suppressPackageStartupMessages({
  library(dplyr)
  library(stringr)
})

log_lines <- c()
note <- function(msg) {
  log_lines <<- c(log_lines, msg)
  cat(msg, "\n")
}

df <- read.csv("data/raw/raw_survey_data.csv", stringsAsFactors = FALSE)
note(sprintf("Loaded raw data: %d rows, %d columns", nrow(df), ncol(df)))

## 1. Standardize state names -------------------------------------------------
valid_states <- c("Kaduna", "Kano", "Bauchi", "Gombe", "Katsina", "Jigawa", "Yobe", "Adamawa")
before <- length(unique(df$state))
df$state <- str_to_title(str_trim(df$state))
df$state[df$state == "Adamawah"] <- "Adamawa"
after <- length(unique(df$state))
note(sprintf("Standardized 'state' text (case/whitespace/typo fix): %d raw variants -> %d valid states", before, after))
stopifnot(all(unique(df$state) %in% valid_states))

## 2. Standardize urban_rural whitespace --------------------------------------
df$urban_rural <- str_to_title(str_trim(df$urban_rural))
note("Trimmed whitespace and standardized casing in 'urban_rural'")

## 3. Standardize currently_in_union to 0/1 -----------------------------------
df$currently_in_union <- ifelse(df$currently_in_union %in% c("Yes", "1"), 1L,
                          ifelse(df$currently_in_union %in% c("No", "0"), 0L, NA_integer_))
note("Recoded 'currently_in_union' Yes/No text values to 0/1 integer")

## 4. Fix impossible ages (survey scope is women 15-49) -----------------------
n_bad_age <- sum(df$age < 15 | df$age > 49, na.rm = TRUE)
df <- df %>% filter(age >= 15 & age <= 49)
note(sprintf("Dropped %d records with age outside the 15-49 eligible range (data entry errors)", n_bad_age))

## 5. Remove duplicate records -------------------------------------------------
## Dedupe on respondent_id only: with many low-cardinality survey fields, two
## *different* women can legitimately share an identical covariate profile,
## so full-row deduplication (excluding ID) would wrongly discard real
## observations. respondent_id is the unique survey identifier, so a repeated
## ID is the correct signal of a double-entry error.
n_before <- nrow(df)
df <- df %>% distinct(respondent_id, .keep_all = TRUE)
n_dupes <- n_before - nrow(df)
note(sprintf("Removed %d duplicate records (repeated respondent_id, i.e. double data entry)", n_dupes))

## 6. Handle missing values ----------------------------------------------------
n_missing_educ <- sum(is.na(df$education))
df$education[is.na(df$education)] <- "Missing"
note(sprintf("Flagged %d missing 'education' values as explicit 'Missing' category (not imputed)", n_missing_educ))

n_missing_wealth <- sum(is.na(df$wealth_quintile))
df$wealth_quintile[is.na(df$wealth_quintile)] <- -1
df$wealth_quintile <- as.integer(df$wealth_quintile)
note(sprintf("Flagged %d missing 'wealth_quintile' values as -1 (not imputed)", n_missing_wealth))

n_missing_parity <- sum(is.na(df$parity))
median_parity <- median(df$parity, na.rm = TRUE)
df$parity_imputed <- as.integer(is.na(df$parity))
df$parity[is.na(df$parity)] <- median_parity
df$parity <- as.integer(df$parity)
note(sprintf("Median-imputed %d missing 'parity' values (median=%s); flagged in new 'parity_imputed' indicator column",
             n_missing_parity, median_parity))

## 7. Type cleanup --------------------------------------------------------------
df$age <- as.integer(df$age)
df$wave_year <- as.integer(df$wave_year)
df$treatment_group <- as.integer(df$treatment_group)

## 8. Derived variables useful for analysis ------------------------------------
df$age_group <- cut(df$age, breaks = c(14, 19, 24, 29, 34, 39, 44, 49),
                     labels = c("15-19", "20-24", "25-29", "30-34", "35-39", "40-44", "45-49"))
df$wave <- ifelse(df$wave_year == 2018, "Baseline (2018)", "Endline (2022)")
df$post <- as.integer(df$wave_year == 2022)
df$treat_x_post <- df$treatment_group * df$post
note("Created derived variables: age_group, wave (label), post (0/1), treat_x_post (DiD interaction)")

## 9. Final column order -------------------------------------------------------
cols <- c("respondent_id", "state", "treatment_group", "wave_year", "wave", "post",
          "treat_x_post", "urban_rural", "age", "age_group", "education",
          "wealth_quintile", "parity", "parity_imputed", "religion",
          "currently_in_union", "heard_of_programme",
          "modern_contraceptive_use", "any_contraceptive_use")
df <- df[, cols]

dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)
out_path <- "data/processed/cleaned_survey_data.csv"
write.csv(df, out_path, row.names = FALSE, na = "NA")
note(sprintf("\nFinal cleaned dataset: %d rows, %d columns -> saved to %s", nrow(df), ncol(df), out_path))

writeLines(c("DATA CLEANING LOG", strrep("=", 50), paste("-", log_lines)),
           "data/processed/cleaning_log.txt")
cat("\nCleaning log saved to data/processed/cleaning_log.txt\n")

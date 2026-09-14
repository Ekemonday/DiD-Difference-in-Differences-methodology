## 01_generate_synthetic_data.R
##
## Generates a synthetic, DHS-style dataset simulating a Difference-in-Differences
## evaluation of a hypothetical Nigerian family planning programme:
##   "State Family Planning Support Programme" (SFPSP)
##
## Design mirrors a real repeated cross-sectional household survey:
##   - 2 waves: Baseline (2018) and Endline (2022)
##   - 8 Northern Nigerian states: 4 treatment (SFPSP rolled out 2019-2020), 4 control
##       Treatment: Kaduna, Kano, Bauchi, Gombe
##       Control:   Katsina, Jigawa, Yobe, Adamawa
##   - Outcome: modern contraceptive use among women 15-49 (+ secondary "any method")
##   - A true programme effect + a secular time trend are built into the data-
##     generating process, so the DiD analysis in 04_did_analysis.R should recover
##     a positive, significant effect.
##   - Realistic messiness (typos, missing values, duplicates, inconsistent coding)
##     is injected on purpose, to be fixed in 02_clean_data.R.
##
## Output: data/raw/raw_survey_data.csv
##
## Run from the repository root: Rscript R/01_generate_synthetic_data.R

set.seed(42)

treatment_states <- c("Kaduna", "Kano", "Bauchi", "Gombe")
control_states   <- c("Katsina", "Jigawa", "Yobe", "Adamawa")
all_states       <- c(treatment_states, control_states)

n_per_state_wave <- 940
waves <- c(`0` = 2018, `1` = 2022)

records <- list()
pid <- 100000
row_i <- 0

for (state in all_states) {
  is_treatment <- state %in% treatment_states
  state_effect <- rnorm(1, 0, 0.02)

  for (wave in c(0, 1)) {
    n <- round(rnorm(1, n_per_state_wave, 25))

    for (k in seq_len(n)) {
      pid <- pid + 1
      row_i <- row_i + 1

      urban <- sample(c(0, 1), 1, prob = c(0.68, 0.32))
      age <- as.integer(pmin(pmax(round(rnorm(1, 28, 8)), 15), 49))

      educ_probs_rural <- c(0.55, 0.28, 0.14, 0.03)
      educ_probs_urban <- c(0.30, 0.30, 0.28, 0.12)
      base_probs <- if (urban == 1) educ_probs_urban else educ_probs_rural
      wave_shift <- if (wave == 1) 0.02 else 0.0
      p <- base_probs + c(-wave_shift, 0, wave_shift * 0.6, wave_shift * 0.4)
      p <- pmax(p, 0); p <- p / sum(p)
      education <- sample(c("No Education", "Primary", "Secondary", "Higher"), 1, prob = p)

      wealth_quintile <- if (urban == 1) {
        sample(1:5, 1, prob = c(0.10, 0.16, 0.22, 0.26, 0.26))
      } else {
        sample(1:5, 1, prob = c(0.28, 0.24, 0.20, 0.16, 0.12))
      }

      parity <- as.integer(pmin(rpois(1, ifelse(age > 25, 3.2, 1.4)), 12))
      religion <- sample(c("Islam", "Christianity", "Other"), 1, prob = c(0.85, 0.13, 0.02))
      in_union <- if (age >= 18) sample(c(0, 1), 1, prob = c(0.18, 0.82)) else sample(c(0, 1), 1, prob = c(0.55, 0.45))

      if (is_treatment && wave == 1) {
        heard_of_programme <- sample(c(0, 1), 1, prob = c(0.35, 0.65))
      } else if (is_treatment && wave == 0) {
        heard_of_programme <- 0
      } else {
        heard_of_programme <- sample(c(0, 1), 1, prob = c(0.94, 0.06))
      }

      logit <- -2.05
      logit <- logit + switch(education, "Secondary" = 0.35, "Higher" = 0.70, "Primary" = 0.15, 0)
      logit <- logit + 0.05 * (wealth_quintile - 1)
      logit <- logit + ifelse(urban == 1, 0.30, 0)
      logit <- logit + ifelse(in_union == 1, 0.10, -0.25)
      logit <- logit - 0.03 * max(parity - 4, 0)
      logit <- logit + ifelse(age >= 20 && age <= 35, 0.15, -0.05)
      logit <- logit + state_effect
      logit <- logit + ifelse(wave == 1, 0.18, 0)

      programme_effect <- 0.55
      if (is_treatment && wave == 1) {
        logit <- logit + programme_effect
        if (heard_of_programme == 1) logit <- logit + 0.20
      }

      prob_modern <- 1 / (1 + exp(-logit))
      modern_use <- rbinom(1, 1, prob_modern)

      prob_any <- min(max(prob_modern + runif(1, 0.03, 0.09), 0), 0.97)
      any_use <- if (modern_use == 1) 1 else rbinom(1, 1, prob_any - prob_modern)

      records[[row_i]] <- data.frame(
        respondent_id = pid,
        state = state,
        wave_year = waves[[as.character(wave)]],
        treatment_group = as.integer(is_treatment),
        urban_rural = ifelse(urban == 1, "Urban", "Rural"),
        age = age,
        education = education,
        wealth_quintile = wealth_quintile,
        parity = parity,
        religion = religion,
        currently_in_union = in_union,
        heard_of_programme = heard_of_programme,
        modern_contraceptive_use = modern_use,
        any_contraceptive_use = any_use,
        stringsAsFactors = FALSE
      )
    }
  }
}

df <- do.call(rbind, records)
rownames(df) <- NULL
clean_shape <- dim(df)

## ============================================================
## Inject realistic messiness for the cleaning exercise
## ============================================================
messy <- df

mess_state <- function(s) {
  r <- runif(1)
  if (r < 0.03) return(toupper(s))
  if (r < 0.05) return(tolower(s))
  if (r < 0.06 && s == "Adamawa") return("Adamawah")
  s
}
messy$state <- vapply(messy$state, mess_state, character(1))

bad_age_idx <- sample(seq_len(nrow(messy)), 12)
messy$age[bad_age_idx] <- sample(c(5, 9, 12, 61, 87, 99), 12, replace = TRUE)

for (spec in list(list(col = "education", frac = 0.025),
                   list(col = "wealth_quintile", frac = 0.02),
                   list(col = "parity", frac = 0.015))) {
  idx <- sample(seq_len(nrow(messy)), round(nrow(messy) * spec$frac))
  messy[idx, spec$col] <- NA
}

inconsistent_idx <- sample(seq_len(nrow(messy)), 300)
messy$currently_in_union <- as.character(messy$currently_in_union)
messy$currently_in_union[inconsistent_idx] <- ifelse(messy$currently_in_union[inconsistent_idx] == "1", "Yes", "No")

dupe_idx <- sample(seq_len(nrow(messy)), 40)
messy <- rbind(messy, messy[dupe_idx, ])

ws_idx <- sample(seq_len(nrow(messy)), 150)
messy$urban_rural[ws_idx] <- paste0(" ", messy$urban_rural[ws_idx], " ")

messy <- messy[sample(seq_len(nrow(messy))), ]
rownames(messy) <- NULL

dir.create("data/raw", recursive = TRUE, showWarnings = FALSE)
out_path <- "data/raw/raw_survey_data.csv"
write.csv(messy, out_path, row.names = FALSE, na = "NA")
cat(sprintf("Saved %d raw records to %s\n", nrow(messy), out_path))
cat("True underlying (clean, pre-mess) shape:", clean_shape[1], "rows,", clean_shape[2], "cols\n")
print(head(messy, 3))

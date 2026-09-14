# SFPSP Contraceptive Uptake Evaluation

**A Difference-in-Differences evaluation, in R, of whether a family planning programme increased modern contraceptive uptake among women of reproductive age.**

This repository contains a complete, reproducible evaluation pipeline — from synthetic data generation through cleaning, descriptive analysis, Difference-in-Differences (DiD) regression, an interactive dashboard, and a written report — for a hypothetical **State Family Planning Support Programme (SFPSP)** rolled out across four Northern Nigerian states.

> **Note on the data:** No real programme-linked microdata meeting this design's requirements (repeated cross-section, treatment/control states, individual covariates, two survey waves) is publicly available. This project therefore uses a **synthetic, DHS-style dataset** generated in R, with a known true effect built into the data-generating process and realistic data-quality issues (typos, missing values, duplicates) injected on purpose so the cleaning step has something real to do. Effect sizes here are illustrative of *method*, not findings about any real programme.

---

## Research question

**Did the SFPSP increase modern contraceptive uptake among women aged 15–49 in the states where it was implemented?**

Design: repeated cross-sectional survey (2018 baseline, 2022 endline), 4 treatment states (Kaduna, Kano, Bauchi, Gombe) vs. 4 control states (Katsina, Jigawa, Yobe, Adamawa), analysed with Difference-in-Differences.

**Headline result:** a robust, statistically significant increase in modern contraceptive prevalence of **≈ 11–12 percentage points** attributable to the programme (p < 0.001), stable across specifications, with a baseline placebo check showing no significant pre-existing treatment/control gap (supporting the parallel-trends assumption). See [`docs/Research_Report.docx`](docs/Research_Report.docx) for the full write-up.

---

## Repository structure

```
.
├── README.md                          <- you are here
├── install_packages.R                 <- installs all required R packages
├── run_pipeline.R                     <- master script: runs everything end-to-end
│
├── R/                                  <- all analysis code
│   ├── 01_generate_synthetic_data.R    <- simulates the raw (messy) survey dataset
│   ├── 02_clean_data.R                 <- documented, auditable cleaning pipeline
│   ├── 03_descriptives.R               <- descriptive stats + ggplot2 visualizations
│   ├── 04_did_analysis.R               <- Difference-in-Differences regression models
│   └── 05_build_data_dictionary.R      <- builds the Excel data dictionary workbook
│
├── data/
│   ├── raw/
│   │   └── raw_survey_data.csv         <- synthetic raw data (with intentional messiness)
│   └── processed/
│       ├── cleaned_survey_data.csv     <- analysis-ready cleaned dataset
│       └── cleaning_log.txt            <- step-by-step log of every cleaning decision
│
├── outputs/
│   ├── Cleaned_Dataset_and_Data_Dictionary.xlsx   <- data + dictionary + cleaning log, one workbook
│   ├── figures/                        <- all charts (PNG), also embedded in the report
│   ├── tables/                         <- descriptive summary tables (CSV)
│   └── regression/                     <- full regression output + coefficient summary (CSV/TXT)
│
├── dashboard/
│   └── SFPSP_Evaluation_Dashboard.html <- standalone interactive dashboard (open in any browser)
│
└── docs/
    ├── Research_Proposal_and_Evaluation_Design.docx   <- design doc: hypotheses, DiD methodology, ethics
    └── Research_Report.docx                            <- 3-page findings report with charts
```

---

## Quick start

### 1. Install R

You need **R ≥ 4.1** (developed and tested on R 4.3.3). Download from [cran.r-project.org](https://cran.r-project.org/).

### 2. Clone and install dependencies

```bash
git clone https://github.com/<your-username>/SFPSP-Contraceptive-DiD-Evaluation.git
cd SFPSP-Contraceptive-DiD-Evaluation
Rscript install_packages.R
```

This installs: `dplyr`, `tidyr`, `stringr`, `ggplot2`, `ggpubr`, `scales`, `sandwich`, `lmtest`, `openxlsx`.

### 3. Run the full pipeline

```bash
Rscript run_pipeline.R
```

This single command reproduces everything from scratch: generates the raw synthetic dataset, cleans it, produces all descriptive tables and charts, runs the DiD regressions, and builds the Excel data dictionary. Total runtime is a couple of minutes on a typical laptop.

To run an individual stage instead (e.g., just the regression), source it directly with the repo root as your working directory:

```r
setwd("SFPSP-Contraceptive-DiD-Evaluation")
source("R/04_did_analysis.R")
```

### 4. View the outputs

- Open `dashboard/SFPSP_Evaluation_Dashboard.html` directly in a browser (double-click it, or `open dashboard/SFPSP_Evaluation_Dashboard.html` on macOS / `xdg-open` on Linux). It needs an internet connection the first time to load the charting library from a CDN; after that it works offline.
- Open `docs/Research_Report.docx` for the written findings, or `docs/Research_Proposal_and_Evaluation_Design.docx` for the evaluation design and methodology.
- Open `outputs/Cleaned_Dataset_and_Data_Dictionary.xlsx` for the data, variable-by-variable documentation, and cleaning log.

---

## Pipeline details

### Stage 1 — `01_generate_synthetic_data.R`
Simulates ~14,900 individual survey records (women 15–49) across 8 states and 2 waves. A true programme effect and a secular time trend are baked into the data-generating process via a logistic model, so the DiD analysis in Stage 4 should recover a positive, significant effect. Realistic data-quality problems are injected on purpose: inconsistent state-name spelling/casing, a handful of implausible ages, missing values in education/wealth/parity, ~40 duplicate entries, and inconsistent Yes/No vs. 0/1 coding. `set.seed(42)` makes generation fully reproducible.

### Stage 2 — `02_clean_data.R`
A fully auditable cleaning pipeline: every transformation is logged with a plain-language explanation to `data/processed/cleaning_log.txt`. Missingness is **flagged explicitly, not silently imputed**, except for a small amount of parity missingness (median-imputed with a companion `parity_imputed` indicator column so analysts can check sensitivity to that choice). Duplicates are identified by repeated `respondent_id` only — not by matching all fields — because two different respondents can legitimately share the same demographic profile in survey data.

### Stage 3 — `03_descriptives.R`
Produces the core descriptive picture with `ggplot2`: the treatment-vs-control trend line (the visual heart of the DiD design), state-by-state detail, and breakdowns of contraceptive use by education, wealth, and urban/rural residence. Also outputs a baseline covariate-balance table, which is the first check on whether the DiD design is credible.

### Stage 4 — `04_did_analysis.R`
Estimates three linear probability models with `lm()`:
1. A simple 2×2 DiD (treatment × post interaction only)
2. A covariate-adjusted model with state fixed effects (age, education, wealth, parity, urban/rural, union status)
3. The same adjusted model on the secondary outcome (any-method use, not just modern methods)

All standard errors are **clustered by state** using `sandwich::vcovCL()` + `lmtest::coeftest()` — the standard R approach, equivalent to Stata's `, cluster(state)`. A baseline-only placebo regression checks whether treatment and control states already differed before the programme began (they don't, which supports the parallel-trends assumption).

### Stage 5 — `05_build_data_dictionary.R`
Assembles the cleaned dataset, a full variable-by-variable data dictionary, and the cleaning log into a single, styled Excel workbook using `openxlsx`.

---

## Methodology summary

**Estimating equation:**

```
Y_ist = β0 + β1·Treat_s + β2·Post_t + β3·(Treat_s × Post_t) + X_ist'γ + δ_s + ε_ist
```

where `Y_ist` is modern contraceptive use for woman *i* in state *s* at time *t*; `Treat_s` marks a treatment-group state; `Post_t` marks the 2022 endline wave; `X_ist` is a vector of individual covariates; `δ_s` are state fixed effects; and standard errors are clustered by state. **β3** is the DiD estimate of the programme's effect — the coefficient reported throughout this repository.

Full rationale, hypotheses, identifying assumptions, and limitations are documented in [`docs/Research_Proposal_and_Evaluation_Design.docx`](docs/Research_Proposal_and_Evaluation_Design.docx).

---

## Limitations

- **Two waves only.** A formal multi-period pre-trend (event-study) test isn't possible; the parallel-trends assumption rests on a single baseline comparison and contextual judgement.
- **Non-random assignment.** States were not randomly assigned to the programme, so unobserved time-varying confounders cannot be fully ruled out.
- **Self-reported outcomes.** Contraceptive use is self-reported and may be subject to social desirability or recall bias.
- **Repeated cross-section, not a panel.** The design estimates population-level average effects, not individual-level change over time.
- **Synthetic data.** This is a methods demonstration. Effect sizes reflect the values programmed into the data-generating process in Stage 1, not an empirical finding about any real programme.

---

## Reproducibility

- Random seed fixed with `set.seed(42)` in Stage 1 — regenerating the raw data produces identical results.
- All file paths in the `R/` scripts are relative to the repository root, so the pipeline runs identically on any machine after cloning.
- `install_packages.R` pins the exact package list needed; no other dependencies are required.

---

## License

This project is released under the MIT License — see [`LICENSE`](LICENSE).

## Citation / attribution

If you build on this repository, a link back is appreciated. This is a synthetic, methods-training dataset and analysis — not a real programme evaluation — and should not be cited as evidence about any actual family planning programme.

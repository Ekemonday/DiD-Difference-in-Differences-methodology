## 05_build_data_dictionary.R
##
## Builds the 'Cleaned_Dataset_and_Data_Dictionary.xlsx' deliverable:
##   Sheet 1: Data Dictionary
##   Sheet 2: Cleaned Data
##   Sheet 3: Cleaning Log
##
## Output: outputs/Cleaned_Dataset_and_Data_Dictionary.xlsx
##
## Run from the repository root: Rscript R/05_build_data_dictionary.R

suppressPackageStartupMessages(library(openxlsx))

df <- read.csv("data/processed/cleaned_survey_data.csv", stringsAsFactors = FALSE)
cleaning_log <- readLines("data/processed/cleaning_log.txt")

dictionary <- data.frame(
  Variable = c("respondent_id","state","treatment_group","wave_year","wave","post",
               "treat_x_post","urban_rural","age","age_group","education",
               "wealth_quintile","parity","parity_imputed","religion",
               "currently_in_union","heard_of_programme",
               "modern_contraceptive_use","any_contraceptive_use"),
  Type = c("Numeric (ID)","Text (categorical)","Binary","Numeric (year)","Text (categorical)","Binary",
           "Binary","Text (categorical)","Numeric","Text (categorical)","Text (categorical)",
           "Numeric (ordinal)","Numeric","Binary","Text (categorical)",
           "Binary","Binary","Binary (PRIMARY OUTCOME)","Binary (secondary outcome)"),
  Description = c(
    "Unique respondent identifier",
    "Nigerian state of residence",
    "1 = respondent's state received the SFPSP programme; 0 = control state",
    "Survey wave year",
    "Labeled survey wave",
    "1 = endline (post-programme) wave, 0 = baseline",
    "Interaction term treatment_group x post; the DiD estimator variable",
    "Place of residence",
    "Respondent age in completed years at interview",
    "5-year age band derived from age",
    "Highest level of education completed",
    "Household wealth quintile (1=poorest, 5=richest); -1 = missing/not reported",
    "Number of children ever born",
    "1 = parity value was missing in raw data and median-imputed; 0 = original value",
    "Respondent's stated religion",
    "1 = currently married or living with a partner",
    "1 = respondent reports exposure to SFPSP messaging/services (mechanism variable)",
    "1 = currently using a modern contraceptive method (pill, injectable, IUD, implant, condom, sterilization, etc.)",
    "1 = currently using any method, modern or traditional"
  ),
  Values = c(
    "100001-125000 (unique integer)",
    "Kaduna, Kano, Bauchi, Gombe (treatment); Katsina, Jigawa, Yobe, Adamawa (control)",
    "0, 1",
    "2018 (baseline), 2022 (endline)",
    "Baseline (2018), Endline (2022)",
    "0, 1",
    "0, 1",
    "Urban, Rural",
    "15-49",
    "15-19, 20-24, ..., 45-49",
    "No Education, Primary, Secondary, Higher, Missing",
    "-1, 1, 2, 3, 4, 5",
    "0-12 (median-imputed where originally missing)",
    "0, 1",
    "Islam, Christianity, Other",
    "0, 1",
    "0, 1",
    "0, 1",
    "0, 1"
  ),
  stringsAsFactors = FALSE
)

NAVY <- "#1F4E78"
wb <- createWorkbook()

## ---------- Sheet 1: Data Dictionary ----------
addWorksheet(wb, "Data Dictionary")
title_style <- createStyle(fontSize = 14, fontColour = "white", fgFill = NAVY, textDecoration = "bold",
                            halign = "center", valign = "center")
note_style <- createStyle(fontSize = 9, textDecoration = "italic", wrapText = TRUE, valign = "top")
header_style <- createStyle(fontSize = 11, fontColour = "white", fgFill = NAVY, textDecoration = "bold",
                             halign = "center", valign = "center", wrapText = TRUE)
body_style <- createStyle(fontSize = 10, wrapText = TRUE, valign = "top")
alt_style <- createStyle(fontSize = 10, wrapText = TRUE, valign = "top", fgFill = "#F2F2F2")

mergeCells(wb, "Data Dictionary", cols = 1:4, rows = 1)
writeData(wb, "Data Dictionary", "Data Dictionary - SFPSP Contraceptive Uptake Evaluation Dataset", startRow = 1, startCol = 1)
addStyle(wb, "Data Dictionary", title_style, rows = 1, cols = 1:4)
setRowHeights(wb, "Data Dictionary", rows = 1, heights = 24)

mergeCells(wb, "Data Dictionary", cols = 1:4, rows = 2)
note_text <- paste("SOURCE NOTE: This is a SYNTHETIC dataset built to mimic a DHS-style repeated cross-sectional",
                    "household survey (Nigeria, Northern states), constructed for methods training / evaluation",
                    "design practice. It is not real programme data. N =", nrow(df),
                    "women aged 15-49 across 2 waves (2018 baseline, 2022 endline) and 8 states (4 treatment, 4 control).",
                    "Generated entirely in R (see R/ scripts in this repository).")
writeData(wb, "Data Dictionary", note_text, startRow = 2, startCol = 1)
addStyle(wb, "Data Dictionary", note_style, rows = 2, cols = 1:4)
setRowHeights(wb, "Data Dictionary", rows = 2, heights = 45)

writeData(wb, "Data Dictionary", dictionary, startRow = 4, startCol = 1, headerStyle = header_style)
for (i in seq_len(nrow(dictionary))) {
  st <- if (i %% 2 == 0) alt_style else body_style
  addStyle(wb, "Data Dictionary", st, rows = 4 + i, cols = 1:4)
}
setColWidths(wb, "Data Dictionary", cols = 1:4, widths = c(24, 20, 55, 45))
freezePane(wb, "Data Dictionary", firstActiveRow = 5)

## ---------- Sheet 2: Cleaned Data ----------
addWorksheet(wb, "Cleaned Data")
writeData(wb, "Cleaned Data", df, headerStyle = header_style)
setColWidths(wb, "Cleaned Data", cols = 1:ncol(df), widths = "auto")
freezePane(wb, "Cleaned Data", firstActiveRow = 2)

## ---------- Sheet 3: Cleaning Log ----------
addWorksheet(wb, "Cleaning Log")
writeData(wb, "Cleaning Log", "Data Cleaning Log", startRow = 1, startCol = 1)
addStyle(wb, "Cleaning Log", title_style, rows = 1, cols = 1)
setRowHeights(wb, "Cleaning Log", rows = 1, heights = 20)
writeData(wb, "Cleaning Log", data.frame(cleaning_log), startRow = 3, startCol = 1, colNames = FALSE)
setColWidths(wb, "Cleaning Log", cols = 1, widths = 110)

dir.create("outputs", recursive = TRUE, showWarnings = FALSE)
out_path <- "outputs/Cleaned_Dataset_and_Data_Dictionary.xlsx"
saveWorkbook(wb, out_path, overwrite = TRUE)
cat("Saved workbook to", out_path, "\n")
cat("Rows in cleaned data sheet:", nrow(df), "\n")

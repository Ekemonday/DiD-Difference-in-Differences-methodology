## 03_descriptives.R
##
## Descriptive statistics and ggplot2 visualizations.
##
## Outputs:
##   outputs/figures/*.png
##   outputs/tables/descriptive_summary_modern_cpr.csv
##   outputs/tables/baseline_covariate_balance.csv
##
## Run from the repository root: Rscript R/03_descriptives.R

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(scales)
})

df <- read.csv("data/processed/cleaned_survey_data.csv", stringsAsFactors = FALSE)
df$group_label <- factor(ifelse(df$treatment_group == 1, "Treatment states", "Control states"),
                          levels = c("Treatment states", "Control states"))

FIG <- "outputs/figures"
TAB <- "outputs/tables"
dir.create(FIG, recursive = TRUE, showWarnings = FALSE)
dir.create(TAB, recursive = TRUE, showWarnings = FALSE)

NAVY <- "#0C2D48"
NAVY_LIGHT <- "#14508A"
AMBER <- "#BA7517"
LIGHTBLUE <- "#9DC3E6"

theme_report <- theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold", size = 12.5),
    legend.position = "top",
    legend.title = element_blank()
  )

## ---------- 1. Trend line: modern CPR by group over waves ----------
trend <- df %>%
  group_by(wave_year, group_label) %>%
  summarise(modern_cpr = mean(modern_contraceptive_use) * 100, .groups = "drop")

p1 <- ggplot(trend, aes(x = wave_year, y = modern_cpr, color = group_label, group = group_label)) +
  geom_vline(xintercept = 2019.5, linetype = "dashed", color = "gray60") +
  annotate("text", x = 2019.6, y = min(trend$modern_cpr) + 0.5, label = "Programme rollout",
           angle = 90, hjust = 0, size = 3, color = "gray50") +
  geom_line(linewidth = 1.3) +
  geom_point(size = 4) +
  scale_color_manual(values = c("Treatment states" = NAVY_LIGHT, "Control states" = AMBER)) +
  scale_x_continuous(breaks = c(2018, 2022)) +
  labs(title = "Modern Contraceptive Use: Treatment vs Control States (2018-2022)",
       x = "Survey wave", y = "Modern contraceptive prevalence (%)") +
  theme_report
ggsave(file.path(FIG, "01_trend_did.png"), p1, width = 8, height = 4.8, dpi = 150)

## ---------- 2. Bar chart: baseline vs endline by group ----------
p2 <- ggplot(trend, aes(x = group_label, y = modern_cpr, fill = factor(wave_year))) +
  geom_col(position = position_dodge(width = 0.6), width = 0.55) +
  scale_fill_manual(values = c("2018" = LIGHTBLUE, "2022" = NAVY)) +
  labs(title = "Modern CPR by Group and Wave", x = NULL, y = "Modern contraceptive prevalence (%)", fill = "Wave") +
  theme_report
ggsave(file.path(FIG, "02_bar_group_wave.png"), p2, width = 7, height = 4.5, dpi = 150)

## ---------- 3. State-level bar chart ----------
state_trend <- df %>%
  group_by(state, wave_year, treatment_group) %>%
  summarise(modern_cpr = mean(modern_contraceptive_use) * 100, .groups = "drop")

state_order <- df %>% distinct(state, treatment_group) %>% arrange(desc(treatment_group), state) %>% pull(state)
state_trend$state <- factor(state_trend$state, levels = state_order)

p3 <- ggplot(state_trend, aes(x = state, y = modern_cpr, fill = factor(wave_year))) +
  geom_col(position = position_dodge(width = 0.7), width = 0.6) +
  geom_vline(xintercept = 4.5, linetype = "dotted", color = "black") +
  scale_fill_manual(values = c("2018" = LIGHTBLUE, "2022" = NAVY)) +
  labs(title = "Modern Contraceptive Prevalence by State and Wave",
       x = NULL, y = "Modern contraceptive prevalence (%)", fill = "Wave") +
  annotate("text", x = 2.5, y = max(state_trend$modern_cpr) * 1.05, label = "Treatment states", fontface = "bold", size = 3.5) +
  annotate("text", x = 6.5, y = max(state_trend$modern_cpr) * 1.05, label = "Control states", fontface = "bold", size = 3.5) +
  coord_cartesian(clip = "off") +
  theme_report
ggsave(file.path(FIG, "03_state_level.png"), p3, width = 9, height = 5, dpi = 150)

## ---------- 4. Covariate distributions ----------
p4a <- ggplot(df, aes(x = factor(education, levels = c("No Education","Primary","Secondary","Higher","Missing")))) +
  geom_bar(fill = NAVY) + labs(title = "Education", x = NULL, y = "Count") +
  theme_report + theme(axis.text.x = element_text(angle = 30, hjust = 1), legend.position = "none")
p4b <- ggplot(df, aes(x = urban_rural)) +
  geom_bar(fill = NAVY) + labs(title = "Residence", x = NULL, y = "Count") + theme_report + theme(legend.position="none")
p4c <- ggplot(df, aes(x = age)) +
  geom_histogram(bins = 20, fill = NAVY) + labs(title = "Age distribution", x = "Age", y = "Count") + theme_report + theme(legend.position="none")

if (requireNamespace("ggpubr", quietly = TRUE)) {
  library(ggpubr)
  p4 <- ggarrange(p4a, p4b, p4c, ncol = 3)
  ggsave(file.path(FIG, "04_covariates.png"), p4, width = 13, height = 4, dpi = 150)
} else {
  ggsave(file.path(FIG, "04a_education.png"), p4a, width = 5, height = 4, dpi = 150)
  ggsave(file.path(FIG, "04b_residence.png"), p4b, width = 5, height = 4, dpi = 150)
  ggsave(file.path(FIG, "04c_age.png"), p4c, width = 5, height = 4, dpi = 150)
}

## ---------- 5. Modern CPR by education & wealth (endline, treatment) ----------
endline_treat <- df %>% filter(wave_year == 2022, treatment_group == 1)

educ_means <- endline_treat %>%
  filter(education %in% c("No Education","Primary","Secondary","Higher")) %>%
  group_by(education) %>% summarise(modern_cpr = mean(modern_contraceptive_use) * 100) %>%
  mutate(education = factor(education, levels = c("No Education","Primary","Secondary","Higher")))

p5a <- ggplot(educ_means, aes(x = education, y = modern_cpr)) +
  geom_col(fill = NAVY, width = 0.6) +
  labs(title = "Modern CPR by Education\n(Treatment states, endline)", x = NULL, y = "Modern CPR (%)") +
  theme_report + theme(axis.text.x = element_text(angle = 20, hjust = 1), legend.position = "none")

wealth_means <- endline_treat %>% filter(wealth_quintile > 0) %>%
  group_by(wealth_quintile) %>% summarise(modern_cpr = mean(modern_contraceptive_use) * 100)

p5b <- ggplot(wealth_means, aes(x = factor(wealth_quintile), y = modern_cpr)) +
  geom_col(fill = NAVY, width = 0.6) +
  labs(title = "Modern CPR by Wealth Quintile\n(Treatment states, endline)",
       x = "Wealth quintile (1=poorest, 5=richest)", y = "Modern CPR (%)") +
  theme_report + theme(legend.position = "none")

if (requireNamespace("ggpubr", quietly = TRUE)) {
  p5 <- ggarrange(p5a, p5b, ncol = 2)
  ggsave(file.path(FIG, "05_educ_wealth.png"), p5, width = 11, height = 4.5, dpi = 150)
} else {
  ggsave(file.path(FIG, "05a_education_cpr.png"), p5a, width = 5.5, height = 4.5, dpi = 150)
  ggsave(file.path(FIG, "05b_wealth_cpr.png"), p5b, width = 5.5, height = 4.5, dpi = 150)
}

## ---------- Summary tables ----------
summary1 <- df %>% group_by(group_label, wave) %>%
  summarise(modern_cpr = round(mean(modern_contraceptive_use) * 100, 1), n = n(), .groups = "drop")
summary_any <- df %>% group_by(group_label, wave) %>%
  summarise(any_cpr = round(mean(any_contraceptive_use) * 100, 1), n = n(), .groups = "drop")

baseline <- df %>% filter(wave_year == 2018)
covariate_balance <- baseline %>% group_by(group_label) %>%
  summarise(
    mean_age = round(mean(age), 2),
    pct_urban = round(mean(urban_rural == "Urban") * 100, 2),
    mean_parity = round(mean(parity), 2),
    pct_secondary_plus = round(mean(education %in% c("Secondary", "Higher")) * 100, 2),
    mean_wealth = round(mean(wealth_quintile[wealth_quintile > 0]), 2)
  )

cat("=== Modern CPR by group & wave ===\n"); print(summary1)
cat("\n=== Any-method CPR by group & wave ===\n"); print(summary_any)
cat("\n=== Baseline covariate balance (treatment vs control) ===\n"); print(covariate_balance)

write.csv(summary1, file.path(TAB, "descriptive_summary_modern_cpr.csv"), row.names = FALSE)
write.csv(covariate_balance, file.path(TAB, "baseline_covariate_balance.csv"), row.names = FALSE)

cat("\nAll figures saved to", FIG, "\n")

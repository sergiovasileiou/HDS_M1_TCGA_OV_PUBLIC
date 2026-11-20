# 08_model.R
# Fits the logistic regression of platinum resistance at six months on residual
# disease, stage and age, then the sensitivity analyses.
# Reads: outputs/ard_tcga_ov.csv
# Saves: outputs/model_main.csv, outputs/model_s1_12m.csv,
#        outputs/model_no_redacted.csv, outputs/model_summary.csv,
#        outputs/in_vs_out.csv and outputs/model_180.csv

library(here)
library(dplyr)
library(broom)

ard <- read.csv(here("outputs", "ard_tcga_ov.csv"))


# 1. Prepare the model variables ----
# Resistant is the event (1), sensitive is 0.
# Reference groups: no residual disease and stage III (the largest stage group).
# Age is entered per 10 years so the odds ratio is easier to read.

ard$resistant     <- ifelse(ard$platinum_status == "resistant", 1, 0)
ard$resistant_12m <- ifelse(ard$platinum_status_12m == "resistant", 1, 0)
ard$residual_group <- factor(ard$residual_group, levels = c("none", "1-10 mm", "over 10 mm"))
ard$stage_group    <- factor(ard$stage_group, levels = c("III", "I-II", "IV"))
ard$age_10         <- ard$age / 10


# 2. Main model: resistance at six months ----

model_data <- filter(ard, in_model)

model_main <- glm(resistant ~ residual_group + stage_group + age_10,
                  data = model_data, family = binomial)

# exponentiate = TRUE turns log odds into odds ratios, with 95% confidence intervals
results_main <- tidy(model_main, exponentiate = TRUE, conf.int = TRUE)


# 3. Sensitivity analysis S1: resistance at twelve months ----
# Same covariates; patients classed resistant or sensitive at 12 months

s1_data <- filter(ard,
                  platinum_status_12m %in% c("resistant", "sensitive"),
                  !is.na(age), !is.na(stage_group), !is.na(residual_group))

model_s1 <- glm(resistant_12m ~ residual_group + stage_group + age_10,
                data = s1_data, family = binomial)

results_s1 <- tidy(model_s1, exponentiate = TRUE, conf.int = TRUE)


# 4. Check: the main model without the patients the CDR marks as redacted ----

no_redacted_data <- filter(model_data, !flag_cdr_redacted)

model_no_redacted <- glm(resistant ~ residual_group + stage_group + age_10,
                         data = no_redacted_data, family = binomial)

results_no_redacted <- tidy(model_no_redacted, exponentiate = TRUE, conf.int = TRUE)


# 5. Size of each model and events per parameter ----
# Five parameters besides the intercept: two residual groups, two stage groups, age

model_summary <- data.frame(
  model    = c("main (6 months)", "S1 (12 months)", "without redacted"),
  patients = c(nrow(model_data), nrow(s1_data), nrow(no_redacted_data)),
  resistant = c(sum(model_data$resistant), sum(s1_data$resistant_12m),
                sum(no_redacted_data$resistant)))
model_summary$events_per_parameter <- round(model_summary$resistant / 5, 1)


# 6. Sensitivity analysis S2: patients in the model compared with those left out ----
# Among patients on first-line platinum, so the comparison is like for like

first_line <- filter(ard, !is.na(platinum_status))

in_vs_out <- first_line |>
  group_by(in_model) |>
  summarise(patients            = n(),
            mean_age            = round(mean(age, na.rm = TRUE), 1),
            percent_stage_iv    = round(100 * mean(stage_group == "IV", na.rm = TRUE), 1),
            percent_no_residual = round(100 * mean(residual_group == "none", na.rm = TRUE), 1),
            percent_white       = round(100 * mean(race == "WHITE", na.rm = TRUE), 1),
            percent_died        = round(100 * mean(os_event == 1), 1),
            median_os_days      = median(os_days, na.rm = TRUE),
            mean_diagnosis_year = round(mean(diagnosis_year), 1))


# 7. Post hoc check: six months taken as 180 days instead of 183 ----
# Added after the main results were seen, so it is reported as a post hoc check.
# Same patients and covariates; only the cut-off for resistance moves.

model_data$resistant_180 <- ifelse(model_data$platinum_free_days < 180, 1, 0)

model_180 <- glm(resistant_180 ~ residual_group + stage_group + age_10,
                 data = model_data, family = binomial)

results_180 <- tidy(model_180, exponentiate = TRUE, conf.int = TRUE)


# Check the results ----

print(model_summary)
print(results_main)
print(results_s1)
print(results_no_redacted)
print(results_180)
print(sum(model_data$resistant == 1 & model_data$resistant_180 == 0))   # patients who move
print(in_vs_out)
print(table(model_data$stage_group, model_data$resistant))      # no empty cells
print(table(model_data$residual_group, model_data$resistant))   # no empty cells


# Save ----

write.csv(results_main, here("outputs", "model_main.csv"), row.names = FALSE)
write.csv(results_s1, here("outputs", "model_s1_12m.csv"), row.names = FALSE)
write.csv(results_no_redacted, here("outputs", "model_no_redacted.csv"), row.names = FALSE)
write.csv(model_summary, here("outputs", "model_summary.csv"), row.names = FALSE)
write.csv(in_vs_out, here("outputs", "in_vs_out.csv"), row.names = FALSE)
write.csv(results_180, here("outputs", "model_180.csv"), row.names = FALSE)

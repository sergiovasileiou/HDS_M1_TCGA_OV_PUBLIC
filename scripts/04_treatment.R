# 04_treatment.R
# Finds first-line platinum treatment, records the treatment factors
# and works out platinum status.
# Saves: data/lookup/drug_names_raw.csv, data/derived/platinum.rds and
# outputs/platinum_start_days.csv

library(here)
library(dplyr)

drug     <- readRDS(here("data", "derived", "drug.rds"))
survival <- readRDS(here("data", "derived", "survival.rds"))


# 1. Drug names as written in the raw data ----
# Capitals and no extra spaces, so "carboplatin " and "Carboplatin" match

drug$drug_name  <- toupper(trimws(drug$pharmaceutical_therapy_drug_name))
drug$start_days <- as.numeric(drug$pharmaceutical_tx_started_days_to)
drug$end_days   <- as.numeric(drug$pharmaceutical_tx_ended_days_to)

drug_names <- count(drug, drug_name, sort = TRUE)
write.csv(drug_names, here("data", "lookup", "drug_names_raw.csv"), row.names = FALSE)


# 2. Add the hand-made lookup: platinum or not, and the drug group ----

lookup <- read.csv(here("data", "lookup", "drug_lookup.csv"))
drug <- left_join(drug, lookup, by = "drug_name")


# 3. First-line platinum ----
# A platinum drug that started within 180 days of diagnosis

first_line <- filter(drug, platinum == "yes", start_days <= 180)

# One row per patient: the last platinum dose, when platinum started,
# which platinum drug and how many cycles were recorded.
# max() and min() give NA if any value is missing, so nothing is guessed
first_line <- first_line |>
  group_by(bcr_patient_barcode) |>
  summarise(last_platinum_days = max(end_days),
            days_to_platinum   = min(start_days),
            platinum_agent     = ifelse(n_distinct(drug_group) > 1, "more than one",
                                        first(drug_group)),
            platinum_cycles    = max(as.numeric(pharma_adjuvant_cycles_count)))


# 4. Was a taxane given in the same first-line window? ----

taxane <- filter(drug, drug_group == "taxane", start_days <= 180)
first_line$with_taxane <- ifelse(first_line$bcr_patient_barcode %in% taxane$bcr_patient_barcode,
                                 "yes", "no")


# 5. Platinum-free interval ----

platinum <- left_join(first_line, survival, by = "bcr_patient_barcode")

# Days from the last platinum dose to the cancer coming back
platinum$platinum_free_days <- platinum$first_nte_days - platinum$last_platinum_days

# Days of follow-up after the last platinum dose
platinum$followup_days <- platinum$os_days - platinum$last_platinum_days

# Plausibility: recurrence recorded before the last platinum dose (progressed on treatment)
platinum$flag_recur_before_last_dose <- !is.na(platinum$platinum_free_days) &
  platinum$platinum_free_days < 0


# 6. Platinum status, 6 months (183 days) ----
# The rules are checked in order; the first one that is true is used

platinum$status <- case_when(
  is.na(platinum$last_platinum_days)                                 ~ "no end date",
  !is.na(platinum$first_nte_days) & platinum$platinum_free_days < 183 ~ "resistant",
  !is.na(platinum$first_nte_days)                                    ~ "sensitive",
  platinum$followup_days >= 183                                      ~ "sensitive",
  platinum$os_event == 1                                             ~ "died without recurrence",
  TRUE                                                               ~ "too early")


# 7. Sensitivity analysis S1: the same rules with 12 months (365 days) ----

platinum$status_12m <- case_when(
  is.na(platinum$last_platinum_days)                                 ~ "no end date",
  !is.na(platinum$first_nte_days) & platinum$platinum_free_days < 365 ~ "resistant",
  !is.na(platinum$first_nte_days)                                    ~ "sensitive",
  platinum$followup_days >= 365                                      ~ "sensitive",
  platinum$os_event == 1                                             ~ "died without recurrence",
  TRUE                                                               ~ "too early")


# 8. When did each patient's first platinum start? ----
# Checks the 180-day first-line window: the first start of every patient with any
# platinum row, grouped into time bands. Most should fall well inside 180 days.

first_platinum_any <- drug |>
  filter(platinum == "yes", !is.na(start_days)) |>
  group_by(bcr_patient_barcode) |>
  summarise(first_start = min(start_days))

start_band <- cut(first_platinum_any$first_start,
                  breaks = c(-Inf, 0, 30, 60, 90, 120, 180, 365, Inf),
                  labels = c("day 0 or before", "1 to 30", "31 to 60", "61 to 90",
                             "91 to 120", "121 to 180", "181 to 365", "over 365"))

platinum_start <- as.data.frame(table(days_from_diagnosis = start_band))


# Check the results ----

print(sum(is.na(drug$platinum)))   # rows with no drug name: should be 10
print(table(platinum$status, useNA = "ifany"))
print(table(platinum$status_12m, useNA = "ifany"))
print(table(platinum$platinum_agent, useNA = "ifany"))
print(table(platinum$with_taxane, useNA = "ifany"))
print(sum(platinum$flag_recur_before_last_dose))   # recurrence before last dose: 11
print(platinum_start)                               # first platinum start, all patients with platinum


# Save ----

saveRDS(platinum, here("data", "derived", "platinum.rds"))
write.csv(platinum_start, here("outputs", "platinum_start_days.csv"), row.names = FALSE)
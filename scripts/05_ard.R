# 05_ard.R
# Joins everything into the analysis-ready dataset: one row per patient.
# Reads: docs/data_dictionary_text.csv (written by hand) and data/raw/TCGA-CDR.xlsx (Redaction column only)
# Saves: outputs/ard_tcga_ov.csv, outputs/cohort_flow.csv, outputs/diagnosis_years.csv,
# outputs/source_summary.csv and docs/data_dictionary.csv

library(here)
library(dplyr)

patient   <- readRDS(here("data", "derived", "patient.rds"))
survival <- readRDS(here("data", "derived", "survival.rds"))
platinum  <- readRDS(here("data", "derived", "platinum.rds"))


# 1. Factors recorded at diagnosis ----

covariates <- data.frame(
  bcr_patient_barcode     = patient$bcr_patient_barcode,
  age                     = as.numeric(patient$age_at_initial_pathologic_diagnosis),
  race                    = patient$race,
  ethnicity               = patient$ethnicity,
  stage                   = patient$clinical_stage,
  residual_disease        = patient$residual_disease_largest_nodule,
  grade                   = patient$tumor_grade,
  icd_10                  = patient$icd_10,
  lymphovascular_invasion = patient$lymphovascular_invasion_indicator,
  diagnosis_year          = as.numeric(patient$initial_pathologic_dx_year))


# 2. Stage groups ----
# Stages I and II are small, so they are grouped together

stage_i_ii <- c("Stage IA", "Stage IB", "Stage IC", "Stage IIA", "Stage IIB", "Stage IIC")
stage_iii  <- c("Stage IIIA", "Stage IIIB", "Stage IIIC")
stage_iv   <- c("Stage IV")

covariates$stage_group <- NA
covariates$stage_group[covariates$stage %in% stage_i_ii] <- "I-II"
covariates$stage_group[covariates$stage %in% stage_iii]  <- "III"
covariates$stage_group[covariates$stage %in% stage_iv]   <- "IV"


# 3. Residual disease groups, as in du Bois et al. 2009 ----

covariates$residual_group <- NA
covariates$residual_group[covariates$residual_disease == "No Macroscopic disease"] <- "none"
covariates$residual_group[covariates$residual_disease == "1-10 mm"] <- "1-10 mm"
covariates$residual_group[covariates$residual_disease %in% c("11-20 mm", ">20 mm")] <- "over 10 mm"


# 4. Primary site from the ICD-10 code ----
# C56.9 is the ovary; C48 codes are the peritoneum and retroperitoneum

covariates$primary_site <- NA
covariates$primary_site[covariates$icd_10 == "C56.9"] <- "ovary"
covariates$primary_site[covariates$icd_10 %in% c("C48.0", "C48.1", "C48.2")] <- "peritoneal"


# 5. Grade: flag values that should not appear ----
# G4 does not exist for ovarian cancer (Liu et al. 2018 note it in the TCGA data).
# GB marks a borderline tumour, which is unexpected in a serous carcinoma cohort.
# GX (grade cannot be assessed) is kept as recorded.

covariates$flag_grade_check <- covariates$grade %in% c("G4", "GB")


# 6. Join the factors, survival and platinum status ----

platinum_columns <- select(platinum, bcr_patient_barcode, days_to_platinum,
                           platinum_agent, with_taxane, platinum_cycles,
                           last_platinum_days, platinum_free_days, status, status_12m,
                           flag_recur_before_last_dose)

ard <- left_join(survival, covariates, by = "bcr_patient_barcode")
ard <- left_join(ard, platinum_columns, by = "bcr_patient_barcode")


# 7. Choose and order the final columns ----

ard <- select(ard,
              bcr_patient_barcode, age, race, ethnicity, diagnosis_year,
              stage, stage_group, residual_disease, residual_group,
              grade, primary_site, lymphovascular_invasion,
              days_to_platinum, platinum_agent, with_taxane, platinum_cycles,
              os_event, os_days, pfi_event, pfi_days,
              last_platinum_days, platinum_free_days,
              platinum_status = status, platinum_status_12m = status_12m,
              death_source, nte_source,
              flag_death_conflict, flag_dead_no_date,
              flag_followup_after_death, flag_no_time,
              flag_nte_after_death, flag_negative_days,
              flag_recur_before_last_dose, flag_grade_check)


# 8. Who goes into the model ----
# Resistant or sensitive, with age, stage and residual disease recorded.
# Kept as a column so everyone else stays in the ARD and can be compared (S2).
# The recurrence flag is empty (NA) for patients without first-line platinum

ard$in_model <- ard$platinum_status %in% c("resistant", "sensitive") &
  !is.na(ard$age) & !is.na(ard$stage_group) & !is.na(ard$residual_group)


# 8b. Cases the TCGA-CDR marks as redacted ----
# The CDR notes say only that the column shows "if the case is redacted", not why.
# The patients are kept and flagged, so anyone can leave them out.

cdr <- readxl::read_excel(here("data", "raw", "TCGA-CDR.xlsx"),
                          sheet = "TCGA-CDR", col_types = "text")
redacted <- cdr$bcr_patient_barcode[cdr$type == "OV" & cdr$Redaction %in% "Redacted"]
ard$flag_cdr_redacted <- ard$bcr_patient_barcode %in% redacted


# 9. Cohort flow: how many patients remain at each step ----

cohort_flow <- data.frame(
  step = c("All TCGA-OV patients",
           "First-line platinum within 180 days",
           "Last platinum dose recorded",
           "Classified as resistant or sensitive",
           "Age, stage and residual disease recorded (in the model)"),
  patients = c(nrow(ard),
               sum(!is.na(ard$platinum_status)),
               sum(!is.na(ard$last_platinum_days)),
               sum(ard$platinum_status %in% c("resistant", "sensitive")),
               sum(ard$in_model)))


# 9b. Diagnosis years and where deaths and new tumour events were recorded ----
# The index date distribution and the source contribution summary (Masterclass 2)

diagnosis_years <- as.data.frame(table(diagnosis_year = ard$diagnosis_year))

death_sources <- as.data.frame(table(source = ard$death_source, useNA = "ifany"))
nte_sources   <- as.data.frame(table(source = ard$nte_source, useNA = "ifany"))
source_summary <- rbind(data.frame(recorded = "death day", death_sources),
                        data.frame(recorded = "first new tumour event", nte_sources))


# 10. Data dictionary ----
# The script works out type, missing count and values from the data.
# The descriptions, sources, rules, windows and roles are written by hand
# in docs/data_dictionary_text.csv and joined on here, so the counts never go out of date.

# Values: the categories for text columns, the range for numbers,
# and both values for 0/1 columns such as os_event
values <- sapply(ard, function(x) {
  x <- x[!is.na(x)]
  if (length(unique(x)) > 20 && !is.numeric(x)) {
    paste(length(unique(x)), "unique values")
  } else if (is.numeric(x) && length(unique(x)) <= 2) {
    paste(sort(unique(x)), collapse = ", ")
  } else if (is.numeric(x)) {
    paste(min(x), "to", max(x))
  } else {
    paste(sort(unique(x)), collapse = ", ")
  }
})

dictionary_auto <- data.frame(variable  = names(ard),
                              type      = sapply(ard, class),
                              n_missing = colSums(is.na(ard)),
                              values    = values,
                              row.names = NULL)

dictionary_text <- read.csv(here("docs", "data_dictionary_text.csv"))

dictionary <- left_join(dictionary_auto, dictionary_text, by = "variable")
dictionary <- select(dictionary, variable, type, n_missing, description, values,
                     source, rule, window, role)


# Check the results ----

print(nrow(ard))
print(cohort_flow)
print(table(ard$stage_group, useNA = "ifany"))
print(table(ard$residual_group, useNA = "ifany"))
print(table(ard$platinum_status, useNA = "ifany"))
print(table(ard$platinum_status[ard$in_model]))    # events for the model: 105 resistant
print(table(ard$grade, useNA = "ifany"))
print(table(ard$race, useNA = "ifany"))
print(table(ard$ethnicity, useNA = "ifany"))
print(sum(ard$flag_grade_check))                    # G4 or GB: 3
print(sum(ard$flag_recur_before_last_dose, na.rm = TRUE))   # recurrence before last dose: 11
print(sum(ard$flag_cdr_redacted))                   # redacted in the CDR: 45
print(table(redacted = ard$flag_cdr_redacted, in_model = ard$in_model))
print(diagnosis_years)
print(source_summary)

# How many patients are missing each factor
factor_columns <- c("age", "race", "ethnicity", "diagnosis_year", "stage_group", "residual_group", "grade",
                    "primary_site", "lymphovascular_invasion", "platinum_agent",
                    "with_taxane", "platinum_cycles")
print(colSums(is.na(ard[factor_columns])))

# Variables still without a description: should be none
print(dictionary$variable[is.na(dictionary$description) | dictionary$description == ""])


# Save ----

write.csv(ard, here("outputs", "ard_tcga_ov.csv"), row.names = FALSE)
write.csv(cohort_flow, here("outputs", "cohort_flow.csv"), row.names = FALSE)
write.csv(diagnosis_years, here("outputs", "diagnosis_years.csv"), row.names = FALSE)
write.csv(source_summary, here("outputs", "source_summary.csv"), row.names = FALSE)
write.csv(dictionary, here("docs", "data_dictionary.csv"), row.names = FALSE)
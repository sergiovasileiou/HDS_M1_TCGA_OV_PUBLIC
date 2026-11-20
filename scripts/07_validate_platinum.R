# 07_validate_platinum.R
# Compares derived platinum status with the published cBioPortal label
# (validation), against the target in docs/validation_plan.md.
# Saves: outputs/cbio_linkage.csv, outputs/cbio_coverage.csv, outputs/platinum_crosstab.csv,
#        outputs/validation_platinum.csv and outputs/platinum_disagreements.csv

library(here)
library(dplyr)

platinum <- readRDS(here("data", "derived", "platinum.rds"))
ard      <- read.csv(here("outputs", "ard_tcga_ov.csv"))

# The same file as in explore_tables.R: patientId holds the barcode,
# value holds PLATINUM_STATUS (Sensitive, Resistant or Tooearly)
cbio_raw <- read.csv(here("data", "raw", "cbioportal_platinum.csv"))

cbio <- data.frame(bcr_patient_barcode = cbio_raw$patientId,
                   cbio_status         = tolower(cbio_raw$value))


# 1. Linkage: how many cBioPortal patients match ours, and do they differ? ----

linkage <- data.frame(
  measure = c("cBioPortal patients with a label",
              "duplicate barcodes in cBioPortal",
              "matched to the ARD (any patient)",
              "matched to first-line platinum patients"),
  patients = c(nrow(cbio),
               sum(duplicated(cbio$bcr_patient_barcode)),
               sum(cbio$bcr_patient_barcode %in% ard$bcr_patient_barcode),
               sum(cbio$bcr_patient_barcode %in% platinum$bcr_patient_barcode)))

# Do patients with a cBioPortal label differ from those without?
ard$has_cbio_label <- ard$bcr_patient_barcode %in% cbio$bcr_patient_barcode

cbio_coverage <- ard |>
  group_by(has_cbio_label) |>
  summarise(patients            = n(),
            mean_age            = round(mean(age, na.rm = TRUE), 1),
            percent_white       = round(100 * mean(race == "WHITE", na.rm = TRUE), 1),
            race_missing        = sum(is.na(race)),
            percent_stage_iv    = round(100 * mean(stage_group == "IV", na.rm = TRUE), 1),
            percent_no_residual = round(100 * mean(residual_group == "none", na.rm = TRUE), 1),
            mean_diagnosis_year = round(mean(diagnosis_year, na.rm = TRUE), 1))


# 2. Every combination of our status and theirs ----
# Shows how many patients each excluded group holds, as the validation plan says

compare_all <- inner_join(platinum, cbio, by = "bcr_patient_barcode")
crosstab <- as.data.frame(table(ours = compare_all$status,
                                cbioportal = compare_all$cbio_status,
                                useNA = "ifany"))


# 3. Patients classified resistant or sensitive in both sources ----

compare <- filter(compare_all,
                  status %in% c("resistant", "sensitive"),
                  cbio_status %in% c("resistant", "sensitive"))

agreement_table <- table(ours = compare$status, cbioportal = compare$cbio_status)


# 4. Cohen's kappa: agreement beyond what chance alone would give ----

total <- sum(agreement_table)

# Observed agreement: patients on the diagonal, divided by all patients
p_observed <- sum(diag(agreement_table)) / total

# Agreement expected by chance, from the row and column totals
p_expected <- sum(rowSums(agreement_table) * colSums(agreement_table)) / total^2

kappa <- (p_observed - p_expected) / (1 - p_expected)

platinum_check <- data.frame(patients   = total,
                             agreement  = round(p_observed, 3),
                             kappa      = round(kappa, 3),
                             target     = 0.61,
                             target_met = ifelse(kappa >= 0.61, "yes", "no"))

disagreements <- compare[compare$status != compare$cbio_status, ]


# Check the results ----

print(linkage)
print(cbio_coverage)
print(table(ours = compare_all$status, cbioportal = compare_all$cbio_status, useNA = "ifany"))
print(agreement_table)
print(platinum_check)


# Save ----

write.csv(linkage, here("outputs", "cbio_linkage.csv"), row.names = FALSE)
write.csv(cbio_coverage, here("outputs", "cbio_coverage.csv"), row.names = FALSE)
write.csv(crosstab, here("outputs", "platinum_crosstab.csv"), row.names = FALSE)
write.csv(platinum_check, here("outputs", "validation_platinum.csv"), row.names = FALSE)
write.csv(disagreements, here("outputs", "platinum_disagreements.csv"), row.names = FALSE)
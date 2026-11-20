# 03_survival.R
# Rebuilds overall survival (OS) and the progression-free interval (PFI)
# for each patient, following the TCGA-CDR definitions (Liu et al. 2018).
# Saves: data/derived/survival.rds and outputs/death_no_pfi.csv

library(here)
library(dplyr)

patient  <- readRDS(here("data", "derived", "patient.rds"))
followup <- readRDS(here("data", "derived", "followup.rds"))
nte      <- readRDS(here("data", "derived", "nte.rds"))


# 1. Every contact with each patient ----
# The first form plus every follow-up form, one row per form.
# The form column records where each row came from (provenance)

contacts <- bind_rows(patient = patient, followup = followup, .id = "form")
contacts <- select(contacts, bcr_patient_barcode, form, vital_status, tumor_status,
                   death_days_to, last_contact_days_to)

contacts$death_days_to <- as.numeric(contacts$death_days_to)
contacts$last_contact_days_to <- as.numeric(contacts$last_contact_days_to)


# 2. One death day per patient ----
# If forms disagree, take the earliest and count how many values there were.
# death_source says which form type recorded the death

deaths <- contacts |>
  filter(!is.na(death_days_to)) |>
  group_by(bcr_patient_barcode) |>
  summarise(death_days = min(death_days_to),
            n_death_days = n_distinct(death_days_to),
            death_source = ifelse(n_distinct(form) > 1, "both", first(form)))


# 3. Last contact per patient ----

last_contact <- contacts |>
  filter(!is.na(last_contact_days_to)) |>
  group_by(bcr_patient_barcode) |>
  summarise(last_contact_days = max(last_contact_days_to))


# 4. Status recorded on any form ----

status <- contacts |>
  group_by(bcr_patient_barcode) |>
  summarise(ever_dead = any(vital_status == "Dead", na.rm = TRUE),
            ever_with_tumour = any(tumor_status == "WITH TUMOR", na.rm = TRUE))


# 5. First new tumour event per patient ----

nte$nte_days <- as.numeric(nte$new_tumor_event_dx_days_to)

# Only the first event counts; later ones are recurrences of the same disease.
# nte_source says which table the first event came from
first_nte <- nte |>
  filter(!is.na(nte_days)) |>
  group_by(bcr_patient_barcode) |>
  summarise(first_nte_days = min(nte_days),
            nte_source = source_table[which.min(nte_days)])


# 6. Put the pieces together, starting from every patient ----

survival <- select(patient, bcr_patient_barcode)
survival <- left_join(survival, deaths, by = "bcr_patient_barcode")
survival <- left_join(survival, last_contact, by = "bcr_patient_barcode")
survival <- left_join(survival, status, by = "bcr_patient_barcode")
survival <- left_join(survival, first_nte, by = "bcr_patient_barcode")


# 7. Overall survival ----
# Event: a recorded death. Time: days to death, or to last contact if alive

survival$os_event <- ifelse(!is.na(survival$death_days), 1, 0)
survival$os_days  <- ifelse(survival$os_event == 1,
                            survival$death_days, survival$last_contact_days)


# 8. Progression-free interval ----
# Event: a first new tumour event, or death while recorded with tumour
# Time: days to the new tumour event, otherwise the OS time

survival$pfi_event <- ifelse(!is.na(survival$first_nte_days) |
                               (survival$os_event == 1 & survival$ever_with_tumour), 1, 0)
survival$pfi_days  <- ifelse(!is.na(survival$first_nte_days),
                             survival$first_nte_days, survival$os_days)


# 9. Quality flags: problems are flagged, not removed ----

# Forms gave different death days
survival$flag_death_conflict <- !is.na(survival$n_death_days) & survival$n_death_days > 1

# Recorded as dead, but no death day anywhere
survival$flag_dead_no_date <- survival$ever_dead & is.na(survival$death_days)

# A contact recorded after the death day
survival$flag_followup_after_death <- survival$os_event == 1 &
  !is.na(survival$last_contact_days) &
  survival$last_contact_days > survival$death_days

# No usable time at all
survival$flag_no_time <- is.na(survival$os_days)

# Plausibility: a new tumour event recorded after death
survival$flag_nte_after_death <- !is.na(survival$first_nte_days) &
  survival$os_event == 1 & survival$first_nte_days > survival$death_days

# Plausibility: a negative number of days (before diagnosis)
survival$flag_negative_days <- (!is.na(survival$os_days) & survival$os_days < 0) |
  (!is.na(survival$first_nte_days) & survival$first_nte_days < 0)


# 10. Deaths not counted as PFI events ----
# A death only counts towards PFI if the patient was recorded with tumour.
# This splits those deaths into confirmed tumour-free and tumour status missing.

ids <- survival$bcr_patient_barcode[survival$os_event == 1 & survival$pfi_event == 0]

free_any <- unique(c(patient$bcr_patient_barcode[patient$tumor_status %in% "TUMOR FREE"],
                     followup$bcr_patient_barcode[followup$tumor_status %in% "TUMOR FREE"]))

death_no_pfi <- data.frame(group = c("died with no PFI event",
                                     "recorded tumour-free on a form",
                                     "no tumour status on any form"),
                           patients = c(length(ids),
                                        sum(ids %in% free_any),
                                        sum(!ids %in% free_any)))


# Check the results ----

print(table(OS = survival$os_event, PFI = survival$pfi_event))
print(sum(survival$flag_death_conflict))
print(sum(survival$flag_dead_no_date))
print(sum(survival$flag_followup_after_death))
print(sum(survival$flag_no_time))
print(sum(survival$flag_nte_after_death))
print(sum(survival$flag_negative_days))
print(table(survival$death_source, useNA = "ifany"))
print(death_no_pfi)


# Save ----

saveRDS(survival, here("data", "derived", "survival.rds"))
write.csv(death_no_pfi, here("outputs", "death_no_pfi.csv"), row.names = FALSE)
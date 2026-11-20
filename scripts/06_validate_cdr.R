# 06_validate_cdr.R
# Compares the rebuilt OS and PFI with the published TCGA-CDR (Liu et al. 2018),
# against the targets in docs/validation_plan.md, set before this was run.
# Saves: outputs/validation_cdr.csv, outputs/validation_cdr_reasons.csv,
#        outputs/cdr_disagreements.csv

library(here)
library(dplyr)
library(readxl)

survival <- readRDS(here("data", "derived", "survival.rds"))

# Use the same file name as in explore_tables.R
cdr_file <- here("data", "raw", "TCGA-CDR.xlsx")


# 1. Read the CDR and keep the ovarian patients ----

# Read every column as text, as with the Biotab tables, and convert on purpose below
cdr_raw <- read_excel(cdr_file, sheet = "TCGA-CDR", col_types = "text")
cdr_raw <- cdr_raw[cdr_raw$type == "OV", ]

cdr <- data.frame(bcr_patient_barcode = cdr_raw$bcr_patient_barcode,
                  cdr_os_event  = as.numeric(cdr_raw$OS),
                  cdr_os_days   = as.numeric(cdr_raw$OS.time),
                  cdr_pfi_event = as.numeric(cdr_raw$PFI),
                  cdr_pfi_days  = as.numeric(cdr_raw$PFI.time),
                  cdr_redaction = cdr_raw$Redaction)


# 2. Linkage: patients in one source but not the other ----

ours_only <- nrow(anti_join(survival, cdr, by = "bcr_patient_barcode"))
cdr_only  <- nrow(anti_join(cdr, survival, by = "bcr_patient_barcode"))


# 3. Compare patients found in both ----

compare <- inner_join(survival, cdr, by = "bcr_patient_barcode")

compare$os_event_match  <- compare$os_event == compare$cdr_os_event
compare$pfi_event_match <- compare$pfi_event == compare$cdr_pfi_event
compare$os_days_difference <- compare$os_days - compare$cdr_os_days

# Time is only compared where the OS event agrees, as the validation plan says
compare$os_time_within_30 <- abs(compare$os_days_difference) <= 30


# 4. Reasons for each disagreement ----
# The expected differences in the validation plan are checked first,
# using the flags made in 03_survival.R; anything else is "other".
# %in% TRUE turns a missing comparison into FALSE, so blanks cannot stop the script.

os_ok   <- compare$os_event_match %in% TRUE
time_ok <- compare$os_time_within_30 %in% TRUE
pfi_ok  <- compare$pfi_event_match %in% TRUE
ours_pfi_only <- compare$pfi_event %in% 1 & compare$cdr_pfi_event %in% 0

compare$os_reason <- "agrees"
compare$os_reason[os_ok & !time_ok] <- "time differs by over 30 days: other"
compare$os_reason[os_ok & !time_ok & compare$flag_followup_after_death] <-
  "time differs: contact after death (expected difference 1)"
compare$os_reason[os_ok & !time_ok & compare$flag_death_conflict] <-
  "time differs: forms disagree on death day (expected difference 1)"
compare$os_reason[os_ok & is.na(compare$os_time_within_30)] <- "time missing in one source"
compare$os_reason[!os_ok] <- "event differs: other"
compare$os_reason[!os_ok & compare$flag_dead_no_date] <-
  "event differs: dead with no death day (expected difference 2)"
compare$os_reason[is.na(compare$cdr_os_event)] <- "missing in the CDR"

compare$pfi_reason <- "agrees"
compare$pfi_reason[!pfi_ok] <- "event differs: other"
compare$pfi_reason[!pfi_ok & ours_pfi_only & is.na(compare$first_nte_days)] <-
  "event differs: death with tumour on an earlier form (expected difference 3)"
compare$pfi_reason[!pfi_ok & ours_pfi_only & compare$nte_source %in% "separate_form"] <-
  "event differs: event only in the separate NTE table (expected difference 4)"
compare$pfi_reason[is.na(compare$cdr_pfi_event)] <- "missing in the CDR"


# 5. Results against the targets in the validation plan ----

os_event_agree <- mean(compare$os_event_match, na.rm = TRUE)
os_time_agree  <- mean(compare$os_time_within_30[os_ok], na.rm = TRUE)
pfi_event_agree <- mean(compare$pfi_event_match, na.rm = TRUE)

validation <- data.frame(
  measure  = c("OS event agreement", "OS time within 30 days (matching events)",
               "PFI event agreement"),
  target   = c(0.95, 0.90, 0.85),
  achieved = round(c(os_event_agree, os_time_agree, pfi_event_agree), 3))
validation$target_met <- ifelse(validation$achieved >= validation$target, "yes", "no")


# 6. Counts of disagreements by reason ----

os_reasons  <- as.data.frame(table(reason = compare$os_reason))
pfi_reasons <- as.data.frame(table(reason = compare$pfi_reason))
reasons <- rbind(data.frame(endpoint = "OS", os_reasons),
                 data.frame(endpoint = "PFI", pfi_reasons))

# Every patient who disagrees on anything, for tracing back to the raw rows
disagreements <- compare[compare$os_reason != "agrees" | compare$pfi_reason != "agrees", ]


# Check the results ----

print(ours_only)    # in our data but not the CDR: expected 0
print(cdr_only)     # in the CDR but not our data: expected 0
print(table(compare$cdr_redaction, useNA = "ifany"))   # redacted cases
print(table(ours = compare$os_event, cdr = compare$cdr_os_event))
print(table(ours = compare$pfi_event, cdr = compare$cdr_pfi_event))
print(validation)
print(reasons)


# Save ----

write.csv(validation, here("outputs", "validation_cdr.csv"), row.names = FALSE)
write.csv(reasons, here("outputs", "validation_cdr_reasons.csv"), row.names = FALSE)
write.csv(disagreements, here("outputs", "cdr_disagreements.csv"), row.names = FALSE)
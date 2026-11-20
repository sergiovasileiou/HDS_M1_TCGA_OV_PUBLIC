# Validation plan: TCGA-OV platinum response analysis-ready dataset

Dataset: [outputs/ard_tcga_ov.csv](../outputs/ard_tcga_ov.csv) (587 patients, 36 columns), built from the GDC Biotab clinical tables, data release 46.0, downloaded 11 November 2026.

Abbreviations are listed in [abbreviations.md](abbreviations.md).

Written on the 13th of November, before viewing any outcome values in the TCGA-CDR. Only the sheet name and column names had been read, which confirmed that the same 587 ovarian patients appear in both sources. From cBioPortal, only the counts of its platinum label had been seen (Sensitive 197, Resistant 90, Tooearly 58), not how they compare with my own classification.

## Overall survival

- Agreement with the CDR events: at least 95% of patients in both sources
- Time within 30 days of the CDR: at least 90% of patients with matching events

## Progression-free interval

- Agreement: at least 85%. Lower agreement is expected because PFI depends on new tumour event dates from two tables, which are not as filled as death dates

## Platinum status against cBioPortal

- Cohen's kappa of at least 0.61 (substantial on the Landis and Koch scale)
- Calculated only on patients labelled sensitive or resistant in both sources. Patients classed as too early, died without recurrence or with no end-date in my data, and as Tooearly in cBioPortal, are left out, and the number in each group is reported

## Disagreements

- Every disagreement is grouped by reason, and up to 10 per group are traced back to the raw rows
- I will not change a rule only to improve agreement

## Expected differences (added 18 November 2026, before running the CDR comparison)

From the CDR's notes on how its endpoints were derived, read before viewing any outcome values:

1. OS time: the CDR takes the larger of last contact and death day; this rebuild takes the death day.
2. Dead with no death day: likely an event in the CDR; not an event here, because there is no time.
3. Tumour status: the CDR uses the latest status; this rebuild uses "with tumour" on any form.
4. New tumour events: the CDR uses the follow-up files; this rebuild also uses the separate new tumour event table.

## Changes made after validation

- 18 November 2026: the decisions on seven flagged entries in [data/lookup/drug_lookup.csv](../data/lookup/drug_lookup.csv) were finalised after [06_validate_cdr.R](../scripts/06_validate_cdr.R) and [07_validate_platinum.R](../scripts/07_validate_platinum.R) had been run. Two trial entries (GOG 218 and GOG182) were changed to platinum because every arm of those trials gave carboplatin. The reasons are recorded in the notes column. No patient count, agreement figure or kappa changed.

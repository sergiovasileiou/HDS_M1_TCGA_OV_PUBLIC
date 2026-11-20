# Phenotype specifications: TCGA-OV platinum response analysis-ready dataset

Dataset: [outputs/ard_tcga_ov.csv](../outputs/ard_tcga_ov.csv) (587 patients, 36 columns), built from the GDC Biotab clinical tables, data release 46.0, downloaded 11 November 2026.

Abbreviations are listed in [abbreviations.md](abbreviations.md).

Day 0 for every phenotype is the date of initial pathologic diagnosis; every day field in the Biotab tables counts from it. Counts are from the run of 18 November 2026.

## Overview

| Phenotype | Variables | Population | Role | Code | Checked against | Result |
|---|---|---|---|---|---|---|
| [Overall survival](#1-overall-survival-os_event-os_days) | os_event, os_days | all 587 | pipeline check | [03_survival.R](../scripts/03_survival.R) | TCGA-CDR, event agreement 0.998 | 348 events |
| [Progression-free interval](#2-progression-free-interval-pfi_event-pfi_days) | pfi_event, pfi_days | all 587 | check on the recurrence date | [03_survival.R](../scripts/03_survival.R) | TCGA-CDR, event agreement 0.998 | 413 events |
| [Platinum status, 6 months](#3-platinum-status-at-six-months-platinum_status) | platinum_status | 491 on first-line platinum | model outcome | [04_treatment.R](../scripts/04_treatment.R) | cBioPortal, kappa 0.966 | 111 resistant, 291 sensitive |
| [Platinum status, 12 months](#4-platinum-status-at-twelve-months-platinum_status_12m-sensitivity-analysis-s1) | platinum_status_12m | 491 on first-line platinum | sensitivity analysis S1 | [04_treatment.R](../scripts/04_treatment.R) | none available | 193 resistant, 196 sensitive |

---

## 1. Overall survival (os_event, os_days)

**Purpose.** Not used in the model. Rebuilt from the raw forms to check the pipeline: the CDR built the same endpoint independently, so close agreement shows the patient and follow-up forms were cleaned and joined correctly before the platinum outcome was built from the same days.

| Field | Detail |
|---|---|
| Population | all 587 patients |
| Index date | diagnosis (day 0) |
| Outcome window | any time in follow-up |
| Event | a death day on the patient form or any follow-up form |
| Censoring | latest last contact day, for patients without a death day; no follow-up after 31 July 2015, the last form completed |
| Source fields | death_days_to and last_contact_days_to in clinical_patient_ov and clinical_follow_up_v1.0_ov |
| Repeat observations | one patient form and any number of follow-up forms per patient, combined into one row |
| Quality flags | flag_death_conflict, flag_dead_no_date, flag_followup_after_death, flag_no_time, flag_negative_days |
| Provenance | death_source: both forms 296, follow-up form only 47, patient form only 5 ([outputs/source_summary.csv](../outputs/source_summary.csv)) |
| Code | [scripts/03_survival.R](../scripts/03_survival.R), sections 1 to 3 and 7 |

**Rule.** os_event is 1 if any form has a death day, otherwise 0. os_days is the death day for events and the latest last contact day for everyone else.

**Missing or conflicting data.** If forms give different death days, the earliest is used and flagged. Dead with no death day: not an event, flagged. No death day or last contact day: os_days blank, flagged. Nobody is removed.

**Result.** 348 events; os_days blank for 3 patients.

**Checked against** TCGA-CDR ([Liu et al. 2018](https://doi.org/10.1016/j.cell.2018.02.052)) OS and OS.time ([scripts/06_validate_cdr.R](../scripts/06_validate_cdr.R)):

| Measure | Target | Achieved |
|---|---|---|
| Event agreement | 0.95 | 0.998 (584 of 585) |
| Time within 30 days, matching events | 0.90 | 0.995 (579 of 582) |

Of the 5 patients with matching events but no time agreement, 3 differ by over 30 days and 2 have no time in one source. The one event disagreement is the patient recorded as dead with no death day (expected difference 2). Two patients have no OS value in the CDR.

**Known limitations.**

- **Follow-up.** Collected unevenly across sites, so patients are censored at very different points and a death after the last form would be missed.
- **Missing dates.** The patient recorded as dead with no death day counts as alive here, and the 3 patients with no usable time cannot enter a time-based analysis.
- **Validation.** Agreement with the CDR shows two derivations match, not that the forms are correct, because both start from the same TCGA records.

---

## 2. Progression-free interval (pfi_event, pfi_days)

**Purpose.** Not used in the model. Checked against the CDR because its first new tumour event day is the recurrence date the platinum outcome is built on. If PFI matches an independent derivation, those recurrence dates can be trusted.

| Field | Detail |
|---|---|
| Population | all 587 patients |
| Index date | diagnosis (day 0) |
| Outcome window | any time in follow-up |
| Event | the first new tumour event in either new tumour event table, or death while recorded as with tumour on any form |
| Competing event | death with no tumour recorded; not an event, censored at os_days |
| Censoring | os_days, for patients with no event |
| Source fields | new_tumor_event_dx_days_to in clinical_nte_ov and clinical_follow_up_v1.0_nte_ov; tumor_status in clinical_patient_ov and clinical_follow_up_v1.0_ov; os_event and os_days |
| Repeat observations | several new tumour events across the two tables; only the earliest is used |
| Quality flags | flag_nte_after_death, flag_negative_days |
| Provenance | nte_source: the first event came from the follow-up table for 359 patients and the separate table for 3 ([outputs/source_summary.csv](../outputs/source_summary.csv)) |
| Code | [scripts/03_survival.R](../scripts/03_survival.R), sections 4, 5, 8 and 10 |

**Rule.** pfi_event is 1 if either table has a new tumour event, or if the patient died and any form says WITH TUMOR; otherwise 0. pfi_days is the day of the earliest new tumour event, or os_days if there is none.

**Missing or conflicting data.** If tumour status is missing on every form, a death does not count as an event (27 patients). A new tumour event with no day is not used.

**Result.** 413 events. 34 deaths are not events: 7 were recorded tumour-free and 27 have no tumour status on any form ([outputs/death_no_pfi.csv](../outputs/death_no_pfi.csv)).

**Checked against** TCGA-CDR ([Liu et al. 2018](https://doi.org/10.1016/j.cell.2018.02.052)) PFI ([scripts/06_validate_cdr.R](../scripts/06_validate_cdr.R)):

| Measure | Target | Achieved |
|---|---|---|
| Event agreement | 0.85 | 0.998 (586 of 587) |

The one disagreement is an event in the CDR that is not an event here.

**Known limitations.**

- **Missing tumour status.** 27 patients who died have no tumour status on any form, so their deaths cannot count; if any died with tumour, events are undercounted (a completeness problem in Kahn's terms).
- **Two source tables.** New tumour events sit in two tables with different columns; both are used, and nte_source records which one each first event came from.
- **Validation.** Agreement with the CDR shows two derivations match, but both use the same forms, so a recurrence that was never recorded is missing from both.

---

## 3. Platinum status at six months (platinum_status)

**Purpose.** The outcome of the logistic regression. It turns the dated drug and new tumour event records into the six-month split clinicians use to judge whether platinum is likely to work again, so that residual disease, stage and age can be tested against it.

| Field | Detail |
|---|---|
| Population | patients whose platinum drug started within 180 days of diagnosis: 491 of 587; blank for the other 96 |
| Index date | diagnosis (day 0) |
| Exposure window | platinum started on day 180 or earlier (see the note under this table) |
| Outcome window | from the last first-line platinum dose (last_platinum_days) |
| Source fields | pharmaceutical_therapy_drug_name, pharmaceutical_tx_started_days_to and pharmaceutical_tx_ended_days_to in clinical_drug_ov; the first new tumour event day; os_days and os_event |
| Code list | [data/lookup/drug_lookup.csv](../data/lookup/drug_lookup.csv): 163 drug names as written in the raw table, each marked platinum yes or no and given a drug group, checked by hand |
| Drug decisions | oxaliplatin counts as platinum (3 patients); other hand-checked entries are explained in the notes column of [drug_lookup.csv](../data/lookup/drug_lookup.csv) |
| Repeat observations | several platinum rows per patient; the earliest start, latest end and highest cycle count among first-line rows are used |
| Quality flags | flag_recur_before_last_dose (11 patients, classed resistant) |
| Code | [scripts/04_treatment.R](../scripts/04_treatment.R), sections 1 to 6 |

**Exposure window.** Of 503 patients with any platinum, 483 started within 90 days, 8 between days 91 and 180 and 12 later, so the cut-off falls in a sparse stretch and moving it would change few patients ([outputs/platinum_start_days.csv](../outputs/platinum_start_days.csv)).

**Rule.** Checked in order; the first match is used.

| Order | Status | Condition |
|---|---|---|
| 1 | no end date | a first-line platinum row has no end day |
| 2 | resistant | new tumour event less than 183 days after the last dose, including one before the last dose |
| 3 | sensitive | new tumour event 183 days or more after the last dose |
| 4 | sensitive | no new tumour event, and followed for at least 183 days after the last dose |
| 5 | died without recurrence | no new tumour event, and died within 183 days of the last dose |
| 6 | too early | everyone else: alive, no new tumour event, followed for under 183 days |

Only a new tumour event counts as recurrence. A death with tumour but no new tumour event counts for PFI but falls under rule 4 or 5 here, not rule 2.

**Missing or conflicting data.** A first-line platinum row with no end day: no end date (36 patients), not classified. Drug rows with no drug name: not matched (10 rows).

**Result.** 111 resistant, 291 sensitive, 43 too early, 36 no end date and 10 died without recurrence. The [table under entry 4](#4-platinum-status-at-twelve-months-platinum_status_12m-sensitivity-analysis-s1) compares both cut-offs.

**Checked against** cBioPortal study [ov_tcga_pub](https://www.cbioportal.org/study/summary?id=ov_tcga_pub) (TCGA, Nature 2011; [paper](https://doi.org/10.1038/nature10166)), attribute PLATINUM_STATUS ([scripts/07_validate_platinum.R](../scripts/07_validate_platinum.R)). 335 of the 345 labelled patients had first-line platinum here.

| | cBioPortal resistant | cBioPortal sensitive | cBioPortal too early |
|---|---|---|---|
| Resistant here | 85 | 4 | 3 |
| Sensitive here | 0 | 188 | 20 |
| Too early here | 0 | 0 | 34 |
| No end date here | 1 | 0 | 0 |

Of the 277 classed resistant or sensitive in both sources, 273 agree (0.986); Cohen's kappa 0.966 (target 0.61). Patients with a cBioPortal label are similar to those without on age, stage, residual disease and diagnosis year, but more often white (92.3% vs 85.4% of those with race recorded) and less often missing race (2.3% vs 9.5%), so the comparison rests on a less diverse subset ([outputs/cbio_coverage.csv](../outputs/cbio_coverage.csv)).

**Known limitations.**

- **Cut-off.** Six months is a clinical convention, not a biological boundary; Bookman et al. (2017) describe the interval as best reported as a continuous measure, so patients either side of 183 days may differ little. Six months is taken as 183 days (six calendar months). A post hoc check with 180 days moves 2 model patients (TCGA-09-0365 and TCGA-25-2393, intervals of 181 and 182 days) from resistant to sensitive; residual disease barely changes, but the age interval then includes 1 ([scripts/08_model.R](../scripts/08_model.R), section 7; [outputs/model_180.csv](../outputs/model_180.csv)).
- **Missing end-dates.** 36 patients (7.3% of first-line patients) have no end-date and cannot be classified.
- **Implausible dates.** 11 recurred before their last dose and 3 have end-dates after day 365; a late end-date shortens the interval and pushes a patient towards resistant.
- **Recurrence rule.** A patient who died with tumour but has no new tumour event recorded cannot be classed resistant.
- **Validation.** Agreement with cBioPortal shows this rule reproduces the published label, but that label's rule is not documented, so agreement cannot show which rule is right.

---

## 4. Platinum status at twelve months (platinum_status_12m), sensitivity analysis S1

**Purpose.** Sensitivity analysis S1. Repeats the model with a 12-month cut-off to test whether the six-month results depend on where the line is drawn. Twelve months separates the group Dockery et al. (2019) call partially platinum sensitive (recurrence at 6 to 12 months, worse prognosis) from later recurrences, in whom platinum works best.

| Field | Detail |
|---|---|
| Population, index date, windows, source fields, code list | as for platinum_status |
| Rule | the same six rules, with 365 days in place of 183 in rules 2 to 5 |
| Code | [scripts/04_treatment.R](../scripts/04_treatment.R), section 7 |
| Checked against | no published label uses 12 months; used to test whether the model results depend on the cut-off ([scripts/08_model.R](../scripts/08_model.R)). In the 12-month model (356 patients, 181 resistant), residual disease and age kept the same direction as at six months, with smaller odds ratios |

**Result, both cut-offs** (491 first-line platinum patients):

| Status | 6 months | 12 months |
|---|---|---|
| sensitive | 291 | 196 |
| resistant | 111 | 193 |
| too early | 43 | 54 |
| no end date | 36 | 36 |
| died without recurrence | 10 | 12 |

**Known limitations.**

- **No outside check.** No published label uses 12 months.
- **Follow-up needed.** Patients need a year of follow-up after their last dose to be classed sensitive without a recurrence, so too early rises from 43 to 54.
- **Mixed resistant group.** Resistant rises from 111 to 193: the 82 extra patients recurred between 6 and 12 months, so resistant here mixes two groups clinicians would treat differently.
- **Inherited limitations.** The data limitations of platinum_status still apply: 36 with no end-date, and death with tumour is not counted as recurrence.
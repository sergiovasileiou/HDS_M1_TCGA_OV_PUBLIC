# Dataset metadata: TCGA-OV platinum response analysis-ready dataset

Dataset: [outputs/ard_tcga_ov.csv](../outputs/ard_tcga_ov.csv) (587 patients, 36 columns), built from the GDC Biotab clinical tables, data release 46.0, downloaded 11 November 2026.

Abbreviations are listed in [abbreviations.md](abbreviations.md).

## Description

I rebuilt this analysis-ready dataset from the raw clinical tables of the 587 TCGA ovarian serous cystadenocarcinoma (TCGA-OV) patients. It holds overall survival and the progression-free interval, first-line platinum status at six and twelve months, factors recorded at diagnosis or primary surgery, and quality flags. I built it to test whether residual disease, stage and age are associated with platinum resistance, using logistic regression.

## Unit and size

| Item | Value |
|---|---|
| Unit of observation | one patient, keyed by bcr_patient_barcode |
| Rows | 587 |
| Columns | 36 |
| On first-line platinum (platinum_status not blank) | 491 |
| In the model (in_model is TRUE) | 366 (105 resistant, 261 sensitive) |

Patients are flagged, not removed: everyone stays in the file, and in_model marks the model cohort.

## Columns

Every column is described in full in [docs/data_dictionary.csv](data_dictionary.csv) (type, missing count, description, values, source, rule, window and role). The 36 columns, grouped:

| Group | Columns |
|---|---|
| Key | bcr_patient_barcode |
| Factors at diagnosis (model) | age, stage_group, residual_group |
| Factors at diagnosis (descriptive or raw form) | race, ethnicity, diagnosis_year, stage, residual_disease, grade, primary_site, lymphovascular_invasion |
| First-line platinum exposure | days_to_platinum, platinum_agent, with_taxane, platinum_cycles, last_platinum_days |
| Survival outcomes | os_event, os_days, pfi_event, pfi_days |
| Platinum outcome | platinum_free_days, platinum_status, platinum_status_12m |
| Provenance | death_source, nte_source |
| Quality flags | flag_death_conflict, flag_dead_no_date, flag_followup_after_death, flag_no_time, flag_nte_after_death, flag_negative_days, flag_recur_before_last_dose, flag_grade_check, flag_cdr_redacted |
| Cohort | in_model |

## Source and version

| Item | Value |
|---|---|
| Source | NCI Genomic Data Commons, TCGA-OV BCR Biotab clinical tables |
| Data release | 46.0 |
| Downloaded | 11 November 2026, with TCGAbiolinks 2.40.0 in R 4.6.1 |
| Tables used | clinical_patient_ov, clinical_follow_up_v1.0_ov, clinical_follow_up_v1.0_nte_ov, clinical_nte_ov, clinical_drug_ov |
| Tables not used | radiotherapy and other malignancy tables (nothing needed for the endpoints or model) |
| Join key | bcr_patient_barcode in every table |
| Validation sources | TCGA-CDR Supplementary Table S1, sheet TCGA-CDR ([file](https://api.gdc.cancer.gov/data/1b5f413e-a8d1-4d10-92eb-7c4ae739ed81); [Liu et al. 2018](https://doi.org/10.1016/j.cell.2018.02.052)); cBioPortal study ov_tcga_pub, PLATINUM_STATUS ([study](https://www.cbioportal.org/study/summary?id=ov_tcga_pub); [TCGA Research Network 2011](https://doi.org/10.1038/nature10166)) |

Details of each file I downloaded are in [docs/data_sources.md](data_sources.md).

## Cohort definition

| Item | Value |
|---|---|
| Source population | every patient in the TCGA-OV project (587) |
| Disease definition | TCGA-OV enrolment; all 587 recorded as serous cystadenocarcinoma (histological_type). Tumour tissue site: ovary 582, omentum 3, peritoneum and ovary 2. Primary site kept from ICD-10 (C56.9 ovary; C48.0 to C48.2 peritoneum), recorded for every patient |
| Age range | no restriction |
| Look-back | none: TCGA records start at diagnosis |
| One record per person | one row per bcr_patient_barcode; repeat forms and drug rows collapsed by the rules in phenotypes.md |
| Eligibility for the model | first-line platinum within 180 days of diagnosis; resistant or sensitive; age, stage and residual disease recorded |
| First-line window | of 503 patients with any platinum, 483 (96.0%) started within 90 days of diagnosis, 8 between days 91 and 180, and 12 after day 180 ([outputs/platinum_start_days.csv](../outputs/platinum_start_days.csv)) |
| Exclusion cascade | [outputs/cohort_flow.csv](../outputs/cohort_flow.csv) |

## Cohort description

| Race (as recorded) | Patients | % of 556 with race recorded |
|---|---|---|
| White | 498 | 89.6 |
| Black or African American | 34 | 6.1 |
| Asian | 20 | 3.6 |
| American Indian or Alaska Native | 3 | 0.5 |
| Native Hawaiian or Other Pacific Islander | 1 | 0.2 |
| Not recorded | 31 | |

Ethnicity is recorded for 350 patients (59.6%); 11 of them are Hispanic or Latino. Mean age at diagnosis is about 60 ([outputs/cbio_coverage.csv](../outputs/cbio_coverage.csv)). Patients were diagnosed between 1992 and 2013 (median 2004), and the last follow-up form was completed on 31 July 2015 ([docs/data_sources.md](data_sources.md)).

## Missing values

Missing values are blank in the CSV (NA in R). I set the five TCGA placeholders ([Not Available], [Not Applicable], [Unknown], [Not Evaluated] and [Discrepancy]) to blank in [02_clean.R](../scripts/02_clean.R). The dictionary gives the count of blanks for every column.

## Time convention

All times are whole days since initial pathologic diagnosis (day 0). A negative value means before diagnosis: negative survival or new tumour event days are flagged (flag_negative_days; none found), and one patient's platinum starts on day -8.

## Validation summary

| Check | Target | Achieved |
|---|---|---|
| OS event agreement with the CDR | 0.95 | 0.998 |
| OS time within 30 days, matching events | 0.90 | 0.995 |
| PFI event agreement with the CDR | 0.85 | 0.998 |
| Platinum status, Cohen's kappa against cBioPortal | 0.61 | 0.966 |

I set and dated the targets in [docs/validation_plan.md](validation_plan.md) before running either comparison. Linkage was by exact match on bcr_patient_barcode: all 587 patients matched the CDR, and all 345 cBioPortal patients matched with no duplicates. Patients with a cBioPortal label are similar to those without on age, stage, residual disease and diagnosis year, but more often white (92.3% vs 85.4% of those with race recorded).

## Files

| File | What it holds |
|---|---|
| [outputs/ard_tcga_ov.csv](../outputs/ard_tcga_ov.csv) | the dataset |
| [outputs/cohort_flow.csv](../outputs/cohort_flow.csv) | patients remaining at each inclusion step |
| [outputs/diagnosis_years.csv](../outputs/diagnosis_years.csv) | patients diagnosed in each year (index date distribution) |
| [outputs/source_summary.csv](../outputs/source_summary.csv) | which form recorded each death and which table each first new tumour event |
| [outputs/platinum_start_days.csv](../outputs/platinum_start_days.csv) | first platinum start by time band, for every patient with platinum (checks the 180-day window) |
| [outputs/table_sizes.csv](../outputs/table_sizes.csv), [missing_patient.csv](../outputs/missing_patient.csv), [placeholders.csv](../outputs/placeholders.csv) | profiling of the raw tables (01) |
| [outputs/validation_cdr.csv](../outputs/validation_cdr.csv), [validation_cdr_reasons.csv](../outputs/validation_cdr_reasons.csv), [cdr_disagreements.csv](../outputs/cdr_disagreements.csv), [death_no_pfi.csv](../outputs/death_no_pfi.csv) | comparison with the CDR (03, 06) |
| [outputs/validation_platinum.csv](../outputs/validation_platinum.csv), [platinum_crosstab.csv](../outputs/platinum_crosstab.csv), [platinum_disagreements.csv](../outputs/platinum_disagreements.csv), [cbio_linkage.csv](../outputs/cbio_linkage.csv), [cbio_coverage.csv](../outputs/cbio_coverage.csv) | comparison with cBioPortal (07) |
| [outputs/model_main.csv](../outputs/model_main.csv), [model_s1_12m.csv](../outputs/model_s1_12m.csv), [model_no_redacted.csv](../outputs/model_no_redacted.csv), [model_180.csv](../outputs/model_180.csv), [model_summary.csv](../outputs/model_summary.csv), [in_vs_out.csv](../outputs/in_vs_out.csv) | the model, its sensitivity analyses (S1, S2), the redaction refit and the post hoc 180-day check (08) |
| [docs/data_dictionary.csv](data_dictionary.csv) | every column: type, missing count, description, values, source, rule, window, role (generated by 05_ard.R) |
| [docs/data_dictionary_text.csv](data_dictionary_text.csv) | the hand-written part of the dictionary |
| [docs/phenotypes.md](phenotypes.md) | how overall survival, the progression-free interval and both platinum statuses were derived |
| [docs/traceability.csv](traceability.csv) | each protocol requirement linked to its variables, source, script, check and result |
| [docs/validation_plan.md](validation_plan.md) | targets and expected differences, set before validation |
| [docs/data_sources.md](data_sources.md) | where each source came from and the first look at the raw tables |
| [docs/abbreviations.md](abbreviations.md) | every abbreviation used in the report and documentation |
| [docs/mrc_certificate_sergios_vasileiou.pdf](mrc_certificate_sergios_vasileiou.pdf) | the analyst's MRC training certificate |
| [data/lookup/drug_lookup.csv](../data/lookup/drug_lookup.csv) | the classification of the 163 raw drug names, checked row by row |
| [data/manifests/](../data/manifests/) | checksums, the GDC file list and session information recorded at download |
| [scripts/](../scripts/) | the numbered scripts that build and check the dataset |
| [reports/report.Rmd](../reports/report.Rmd) | the technical report |

## How to rebuild

1. Clone the repository and open *HDS_M1_TCGA_OV.Rproj* in RStudio.
2. Run *renv::restore()* to install the package versions I used.
3. Source *run_all.R*. It runs [00_data_download.R](../scripts/00_data_download.R), which downloads all three sources (the GDC Biotab tables, the CDR table and the cBioPortal label), then the numbered scripts in order. A fresh download gets the current GDC release; this dataset used release 46.0, and later releases may differ.
4. Knit *reports/report.Rmd* in RStudio.

The raw and intermediate data (*data/raw/* and *data/derived/*) are not stored in the repository; the scripts rebuild them. Full instructions are in the [README](../README.md).

## FAIR

| Principle | How this dataset meets it |
|---|---|
| Findable | a fixed name and source release (GDC 46.0); this file and the dictionary describe it; keywords below |
| Accessible | built only from open-access GDC data; anyone can download the source and rebuild it with the scripts |
| Interoperable | plain CSV; TCGA barcodes, the same key the GDC, CDR and cBioPortal use; source column names kept in the dictionary; ICD-10 and FIGO stage values kept as recorded |
| Reusable | every column described with its source, rule and window; derivations specified in phenotypes.md; validation results recorded; flagged patients kept so others can choose their own exclusions |

## Five Safes

| Safe | How it applies to this dataset |
|---|---|
| Safe projects | I built it to answer one stated question, whether residual disease, stage and age are associated with platinum resistance, as part of the Cambridge MSt in Healthcare Data Science. The GDC allows its open-access data to be used in publications with proper accreditation. |
| Safe people | I am the only analyst, and I have completed the Medical Research Council (MRC) course Confidentiality and Data Protection in Health Research, passing the quiz on 24 October 2026 ([certificate](mrc_certificate_sergios_vasileiou.pdf)). |
| Safe settings | I did the work on a personal computer. The raw and intermediate data (data/raw/ and data/derived/) are kept out of Git, and the scripts, documentation and outputs are published in a public GitHub repository. |
| Safe data | I used only open-access GDC clinical data, with no controlled-access data. TCGA barcodes are the only identifiers and every time interval is counted in days from diagnosis; age, race and diagnosis year are kept as the public source records them. |
| Safe outputs | The report shows only counts, percentages, summary statistics and model estimates. One cell is very small (1 resistant patient of 22 at stage I to II), which would usually be suppressed; I report it because the source is already public. The dataset itself is patient-level, but it holds nothing beyond what the GDC already publishes, so sharing it adds little disclosure risk. |

Framework: Desai, Ritchie and Welpton (2016).

## Keywords

TCGA, ovarian cancer, high-grade serous, platinum resistance, platinum-free interval, overall survival, progression-free interval, analysis-ready dataset

## Licence and attribution

The source data are NCI GDC open-access data, which the GDC states can be used in publications or presentations with proper accreditation. Reuse should credit the TCGA Research Network and the NCI Genomic Data Commons.

## Known limitations

- **Representativeness.** This is a research cohort, not a population sample. Of the 556 patients with race recorded, 89.6% are white and 6.1% Black, and ethnicity is missing for 40.4%, so results may not apply to other groups. Spratt et al. (2016) report the same pattern across TCGA.
- **Treatment era.** Patients were diagnosed between 1992 and 2013 (median 2004) and followed up to July 2015 at the latest, so treatment reflects that period.
- **Data collection.** Follow-up and collection rules varied between sites, and stage was recorded under the FIGO version each site used (Liu et al. 2018).
- **Treatment history.** The dataset captures only first-line treatment, so the therapy-free interval now preferred by the GCIG cannot be built from it (Wilson et al. 2017).
- **Drug coding.** Drug names are free text. I classified them in a lookup table, [drug_lookup.csv](../data/lookup/drug_lookup.csv), and checked every row, rather than mapping them to a standard code system.
- **Data quality.** I kept and flagged implausible values rather than removing them; the flags are listed in the dictionary.
- **Validation.** Agreement with the CDR and cBioPortal shows that my rules reproduce published derivations, not that the source forms are correct.
- **Redaction.** The CDR marks 45 patients as redacted without giving a reason. I kept and flagged them (flag_cdr_redacted), so users can leave them out.

Variable-level limitations are in [docs/phenotypes.md](phenotypes.md).

## Contact

Repository: https://github.com/sergiovasileiou/HDS_M1_TCGA_OV_PUBLIC. Author: Sergios Vasileiou, MSt Healthcare Data Science, University of Cambridge.

# TCGA-OV platinum response: an analysis-ready dataset

An analysis-ready dataset of the 587 patients in The Cancer Genome Atlas ovarian serous cystadenocarcinoma project (TCGA-OV), rebuilt from the open clinical tables of the Genomic Data Commons (GDC). It derives first-line platinum status from dated treatment and new tumour event records under a stated six-month rule, flags data quality problems instead of removing patients, and is checked against two published sources. A logistic regression of platinum resistance on residual disease, stage and age shows the dataset in use.

Submitted for Module 1 (HDS261) of the MSt in Healthcare Data Science, University of Cambridge.

**Research question.** Among patients given first-line platinum, are residual disease, stage and age associated with platinum resistance, and does the association hold at a 12-month cut-off?

## Where to start

| If you want | Open |
|---|---|
| The report | [reports/report.html](reports/report.html) (knitted) or [reports/report.Rmd](reports/report.Rmd) (source) |
| The dataset | [outputs/ard_tcga_ov.csv](outputs/ard_tcga_ov.csv) |
| What every column means | [docs/data_dictionary.csv](docs/data_dictionary.csv) |
| How each outcome was derived | [docs/phenotypes.md](docs/phenotypes.md) |
| Dataset metadata, FAIR and Five Safes | [docs/dataset_metadata.md](docs/dataset_metadata.md) |
| To rebuild everything | [How to reproduce](#how-to-reproduce) below |

## Repository structure

```
HDS_M1_TCGA_OV/
├── README.md                  this file
├── HDS_M1_TCGA_OV.Rproj       RStudio project (open this first)
├── .Rprofile                  activates renv when the project opens
├── renv.lock                  exact package versions
├── renv/                      renv set-up files (the library itself is not stored)
├── run_all.R                  rebuilds everything, in order
├── word_count.R               counts the report's words against the 3,000 limit
├── R/
│   └── theme_hds.R            colours and ggplot2 theme for the figure
├── scripts/                   the numbered build scripts (see below)
├── data/
│   ├── lookup/                drug name classification (hand-checked)
│   ├── manifests/             checksums, GDC file list, session information
│   ├── raw/                   downloads (not stored; rebuilt by 00)
│   └── derived/               intermediate tables (not stored; rebuilt by 02 to 04)
├── outputs/                   the dataset and every table the report uses
├── docs/                      dictionary, phenotypes, metadata, validation plan, sources
└── reports/                   report source, knitted report, references and styling
```

## Requirements

- **R 4.6.1** (the version used; recorded in [data/manifests/session_info.txt](data/manifests/session_info.txt)).
- **RStudio**, which supplies Pandoc for knitting the report. Knitting from plain command-line R fails unless Pandoc is installed separately.
- **An internet connection** for the first run, to install packages and download the data.
- **renv**, which installs the exact package versions in [renv.lock](renv.lock), including TCGAbiolinks from Bioconductor.

## How to reproduce

1. **Get the files.** Clone or download this repository.
2. **Open the project.** Open `HDS_M1_TCGA_OV.Rproj` in RStudio. The `.Rprofile` starts renv automatically.
3. **Install the packages.** In the Console:
   ```r
   renv::restore()
   ```
   Type `y` when asked. This installs every package at the version recorded in `renv.lock`.
4. **Rebuild the data, validation and model.** In the Console:
   ```r
   source("run_all.R")
   ```
   On a fresh copy this downloads the data first (step 00), then runs every script in order. Each script runs in its own environment, so nothing left over from one can affect the next.
5. **Knit the report.** Open `reports/report.Rmd` and click **Knit**. Every number in the report is read from `outputs/` by inline R code, so a rebuild updates the report automatically.
6. **Optional: check the word count.**
   ```r
   source(here::here("word_count.R"))
   count_words(here::here("reports", "report.html"))
   ```
   It counts the main text from the Abstract to the References and adds 150 words for each table and figure.

### Tested

A fresh copy of this repository, with no data and no installed packages, was set up with `renv::restore()` and rebuilt with `source("run_all.R")`, which downloaded all three sources again. Every file in `outputs/` came out identical to the submitted files (checked with `diff -r`).

### If you already have the raw data

`run_all.R` skips the download when `data/raw/biotab.rds` exists. It then compares each raw file with the checksum recorded at the original download (11 November 2026) and prints `TRUE` for each file that is unchanged.

### Important: the GDC release

The dataset was built from **GDC data release 46.0**, downloaded on **11 November 2026**. A fresh run downloads the **current** release, which may differ. When it does:

- the raw file checksums will not match the recorded ones;
- step 00 **overwrites** the files in `data/manifests/` with records of the new download. Compare them with the stored versions (for example with `git diff data/manifests/`) to see what changed;
- patient counts and results may differ slightly from the report.

The file IDs and checksums of the release 46.0 files are in [data/manifests/gdc_files.csv](data/manifests/gdc_files.csv) and [data/manifests/download_record.csv](data/manifests/download_record.csv).

## What each script does

| Script | Reads | Saves | Job |
|---|---|---|---|
| [00_data_download.R](scripts/00_data_download.R) | the GDC, CDR and cBioPortal websites | `data/raw/`, `data/manifests/` | downloads the three sources and records checksums and session information |
| [01_profile.R](scripts/01_profile.R) | `data/raw/biotab.rds` | `outputs/table_sizes.csv`, `missing_patient.csv`, `placeholders.csv` | profiles each raw table: size, patient coverage, TCGA placeholders |
| [02_clean.R](scripts/02_clean.R) | `data/raw/biotab.rds` | `data/derived/` | removes the two label rows, sets placeholders to missing, converts types |
| [03_survival.R](scripts/03_survival.R) | `data/derived/` | `data/derived/survival.rds`, `outputs/death_no_pfi.csv` | rebuilds overall survival (OS) and the progression-free interval (PFI), with flags |
| [04_treatment.R](scripts/04_treatment.R) | `data/derived/`, `data/lookup/drug_lookup.csv` | `data/derived/platinum.rds`, `data/lookup/drug_names_raw.csv`, `outputs/platinum_start_days.csv` | identifies first-line platinum and assigns platinum status at 6 and 12 months |
| [05_ard.R](scripts/05_ard.R) | `data/derived/`, `docs/data_dictionary_text.csv`, the CDR | `outputs/ard_tcga_ov.csv`, `docs/data_dictionary.csv`, `outputs/cohort_flow.csv` and others | assembles the dataset, the model cohort flag and the dictionary |
| [06_validate_cdr.R](scripts/06_validate_cdr.R) | `data/derived/survival.rds`, the CDR | `outputs/validation_cdr*.csv`, `cdr_disagreements.csv` | compares OS and PFI with the CDR against the pre-set targets |
| [07_validate_platinum.R](scripts/07_validate_platinum.R) | `data/derived/platinum.rds`, the cBioPortal label | `outputs/validation_platinum.csv`, `platinum_*.csv`, `cbio_*.csv` | compares platinum status with cBioPortal (Cohen's kappa) |
| [08_model.R](scripts/08_model.R) | `outputs/ard_tcga_ov.csv` | `outputs/model_*.csv`, `in_vs_out.csv` | fits the logistic regression, S1, S2, the redaction refit and the post hoc 180-day check |

[scripts/explore_tables.R](scripts/explore_tables.R) is the first look at the raw data that informed [docs/data_sources.md](docs/data_sources.md). It is not part of the build, and `run_all.R` does not run it.

## Data sources

| Source | Use | Access |
|---|---|---|
| GDC, project TCGA-OV, BCR Biotab clinical tables, release 46.0 | builds the dataset | open access; downloaded with TCGAbiolinks |
| TCGA Pan-Cancer Clinical Data Resource (CDR), Liu et al. 2018 | validation of OS and PFI only | open access; GDC file 1b5f413e-a8d1-4d10-92eb-7c4ae739ed81 |
| cBioPortal study `ov_tcga_pub`, attribute PLATINUM_STATUS | validation of platinum status only | open access; cBioPortal web API |

Details, including the first observations on each raw table, are in [docs/data_sources.md](docs/data_sources.md).

## Key definitions

- **Day 0** is the date of initial pathologic diagnosis for every patient.
- **First-line platinum:** platinum started within **180 days** of diagnosis.
- **Platinum status** is assigned by six ordered rules from the **last** first-line platinum dose: **resistant** if a new tumour event came less than **183 days** (six calendar months) after it, or before it; **sensitive** if it came later, or after at least 183 days of follow-up without one. Patients with no end-date, too little follow-up or death without recurrence are not classified. The 12-month status (S1) uses 365 days. The full rules are in [docs/phenotypes.md](docs/phenotypes.md).
- **PFI** always means the CDR's **progression-free interval**, including in the column names `pfi_event` and `pfi_days`. The platinum-free interval is always written in full (column `platinum_free_days`).
- **Patients are flagged, not removed.** All 587 stay in the dataset. `in_model` marks the 366 used in the model, and nine `flag_` columns mark data quality problems, so another analyst can choose different exclusions.

Abbreviations are listed in [docs/abbreviations.md](docs/abbreviations.md).

## Validation

Targets were set and dated in [docs/validation_plan.md](docs/validation_plan.md) before either comparison was run.

| Check | Target | Achieved |
|---|---|---|
| OS event agreement with the CDR | 0.95 | 0.998 |
| OS time within 30 days, matching events | 0.90 | 0.995 |
| PFI event agreement with the CDR | 0.85 | 0.998 |
| Platinum status, Cohen's kappa against cBioPortal (277 patients) | 0.61 | 0.966 |

Every result is in `outputs/`, and every disagreement is listed with its reason in `cdr_disagreements.csv` and `platinum_disagreements.csv`.

## Limitations

The main ones: the cohort was diagnosed between 1992 and 2013 and is predominantly white; a quarter of first-line patients could not enter the model, mainly because of short follow-up or missing end-dates; agreement with the CDR and cBioPortal shows the derivations match, not that the source forms are correct; and drug names are free text classified by hand. The full list is in [docs/dataset_metadata.md](docs/dataset_metadata.md) and, variable by variable, in [docs/phenotypes.md](docs/phenotypes.md).

## Notes

- **Open the report in a web browser.** For the best results, open `reports/report.html` in a web browser such as Chrome, Safari, Firefox or Edge rather than in RStudio's Viewer pane. Some links and interactive features (the contents panel, the supplementary documents, the light and dark switch and the certificate download) may not work there.
- **The report hides its code.** All chunks use `echo = FALSE`, so code does not count towards the word limit. The code is in `reports/report.Rmd` and `scripts/`.
- **Package citations** are written to `reports/packages.bib` on every knit.

## Governance and attribution

The source data are NCI Genomic Data Commons open-access data, which the GDC allows to be used in publications with proper accreditation. Reuse should credit the TCGA Research Network and the NCI Genomic Data Commons, and cite Liu et al. (2018) for the CDR and the cBioPortal papers (Cerami et al. 2012; Gao et al. 2013) for the platinum label. The dataset holds no identifiers other than TCGA barcodes, and all times are days from diagnosis. The Five Safes assessment is in [docs/dataset_metadata.md](docs/dataset_metadata.md).

## Author

Sergios Vasileiou, MSt Healthcare Data Science, University of Cambridge. Use of generative AI is declared on the submission coversheet.

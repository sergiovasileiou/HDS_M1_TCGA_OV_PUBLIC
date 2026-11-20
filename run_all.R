# run_all.R
# Rebuilds the analysis-ready dataset, its documentation, the validation and the
# model from the raw data, by running every script in order.
# Run from the project folder: source("run_all.R")

library(here)


# 1. Make sure the folders exist ----
# data/raw/ and data/derived/ are not stored in Git, so a fresh copy lacks them

for (folder in c("data/raw", "data/derived", "data/manifests", "outputs")) {
  dir.create(here(folder), recursive = TRUE, showWarnings = FALSE)
}


# 2. The scripts, in order ----
# explore_tables.R is left out: it was a first look at the data, not part of the build

scripts <- c("00_data_download.R",
             "01_profile.R",
             "02_clean.R",
             "03_survival.R",
             "04_treatment.R",
             "05_ard.R",
             "06_validate_cdr.R",
             "07_validate_platinum.R",
             "08_model.R")

# Skip the download if the raw files are already here. A new download would get
# the current GDC release, which may differ from release 46.0 used in this project.
if (file.exists(here("data", "raw", "biotab.rds"))) {
  scripts <- scripts[scripts != "00_data_download.R"]
}


# 3. Check the raw files are the ones downloaded on 11 November 2026 ----
# Compares each file's checksum with the one recorded at download

if (file.exists(here("data", "raw", "biotab.rds"))) {
  record  <- read.csv(here("data", "manifests", "download_record.csv"))
  current <- tools::md5sum(here("data", "raw", record$file))
  print(data.frame(file = record$file, unchanged = unname(current) == record$md5))
}


# 4. Run each script ----
# local = new.env() runs each one in its own space, so nothing left over from
# one script can affect the next

for (script in scripts) {
  cat("\nRunning", script, "\n")
  source(here("scripts", script), local = new.env())
}

cat("\nAll scripts finished. Knit reports/report.Rmd to build the report.\n")
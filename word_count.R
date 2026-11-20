# Word counts for the report.
# Use (after knitting):
#   source(here::here("word_count.R"))
#   count_words(here::here("reports", "report.html"))   # the count for the 3,000 limit
#   coversheet_counts()                                  # both coversheet counts
# Words are pieces of text separated by spaces that contain at least one
# letter or digit.

# 3,000-word limit 
# Follows the course rule: the main body counts, including the abstract, and
# each figure, table or shown code snippet counts as 150 words; the
# references, the supplementary documents and the code in report.Rmd don't.
# The report shows no code (echo = FALSE), so only tables and figures add 150.
count_words <- function(html_file) {
  html <- paste(readLines(html_file, warn = FALSE, encoding = "UTF-8"), collapse = " ")
  
  # Keep the main body: from the Abstract heading up to the References heading
  start <- regexpr('id="abstract"', html)
  end   <- regexpr('id="references"', html)
  body  <- substr(html, start, end - 1)
  body  <- sub("^[^>]*>", "", body)   # drop the rest of the opening tag
  body  <- sub("<[^<]*$", "", body)   # drop the start of the References tag
  
  # Count tables and figures (each counts 150 words), then remove them
  n_tables  <- lengths(regmatches(body, gregexpr("<table", body)))
  n_figures <- lengths(regmatches(body, gregexpr("<img", body)))
  body <- gsub("<table.*?</table>", " ", body, perl = TRUE)
  body <- gsub('<p class="caption".*?</p>', " ", body, perl = TRUE)
  body <- gsub("<script.*?</script>|<style.*?</style>", " ", body, perl = TRUE)
  
  # Strip the remaining tags and count words
  text  <- gsub("<[^>]+>", " ", body)
  words <- strsplit(trimws(text), "\\s+")[[1]]
  words <- words[grepl("[[:alnum:]]", words)]
  
  data.frame(text_words  = length(words),
             tables      = n_tables,
             figures     = n_figures,
             total_words = length(words) + 150 * (n_tables + n_figures))
}

# ---- Word counts for the coversheet --------------------------------------
# The coversheet asks for two counts:
#   1. the whole assignment, including code
#   2. the main body, including the abstract and figures, tables or shown code,
#      but excluding references and supplementary materials. This is the same
#      as count_words() above.

count_text <- function(text) {
  words <- unlist(strsplit(paste(text, collapse = " "), "\\s+"))
  sum(grepl("[[:alnum:]]", words))
}

# Count 1: every word in the R Markdown file (the YAML header left out),
# split into the written text and each kind of code chunk; and the same plus
# every R script in the project.
whole_assignment_count <- function(rmd_file, script_files) {
  lines <- readLines(rmd_file, warn = FALSE, encoding = "UTF-8")
  yaml_end <- which(lines == "---")[2]
  lines <- lines[(yaml_end + 1):length(lines)]
  part <- character(length(lines))
  current <- "text"
  for (i in seq_along(lines)) {
    if (current == "text" && grepl("^```\\{", lines[i])) {
      engine <- sub("^```\\{=?([A-Za-z]+).*", "\\1", lines[i])
      current <- switch(engine, r = "R code", css = "CSS code", js = "JavaScript code",
                        html = "HTML and JavaScript code", "other code")
      part[i] <- current
    } else if (current != "text" && grepl("^```\\s*$", lines[i])) {
      part[i] <- current
      current <- "text"
    } else {
      part[i] <- current
    }
  }
  rmd <- sapply(c("text", "R code", "CSS code", "JavaScript code", "HTML and JavaScript code"),
                function(p) count_text(lines[part == p]))
  scripts <- sum(sapply(script_files, function(f) count_text(readLines(f, warn = FALSE))))
  data.frame(part = c(paste("report.Rmd:", names(rmd)), "report.Rmd: total",
                      "R scripts (scripts/, run_all.R, R/, word_count.R)",
                      "Whole assignment including code"),
             words = c(rmd, sum(rmd), scripts, sum(rmd) + scripts),
             row.names = NULL)
}

coversheet_counts <- function() {
  scripts <- c(list.files(here::here("scripts"), pattern = "\\.R$", full.names = TRUE),
               here::here("run_all.R"), here::here("word_count.R"),
               list.files(here::here("R"), pattern = "\\.R$", full.names = TRUE))
  cat("1. Whole assignment including code\n")
  print(whole_assignment_count(here::here("reports", "report.Rmd"), scripts))
  cat("\n2. Main body, including the abstract, excluding references and supplementary materials\n")
  print(count_words(here::here("reports", "report.html")))
  invisible(NULL)
}

# check-setup.R -- run before rehearsing the demo.
# Verifies packages, data columns used by measures/dictionary, Bedrock access.

ok <- function(x, msg) cat(if (x) "OK  " else "FAIL", msg, "\n")

# Packages
for (p in c("commons", "ellmer", "duckdb", "DBI", "dplyr", "pharmaverseadam")) {
  ok(requireNamespace(p, quietly = TRUE), paste("package:", p))
}

# Columns required by measures + dictionary
need <- list(
  adsl = c("USUBJID", "TRT01A", "SAFFL", "AGE", "SEX", "RACE", "EOSSTT"),
  adae = c("USUBJID", "TRT01A", "SAFFL", "TRTEMFL", "AESER", "AESOC",
           "AEDECOD", "AESEV", "ASTDY"),
  adlb = c("USUBJID", "TRTA", "SAFFL", "PARAMCD", "ONTRTFL", "BNRIND",
           "ANRIND", "AVAL")
)
for (tbl in names(need)) {
  have <- names(getExportedValue("pharmaverseadam", tbl))
  missing <- setdiff(need[[tbl]], have)
  ok(length(missing) == 0,
     paste0(tbl, if (length(missing)) paste0(" missing: ",
            paste(missing, collapse = ", ")) else " columns"))
}

# Measures run standalone against DuckDB
con <- DBI::dbConnect(duckdb::duckdb())
DBI::dbWriteTable(con, "adsl", as.data.frame(pharmaverseadam::adsl))
DBI::dbWriteTable(con, "adae", as.data.frame(pharmaverseadam::adae))
DBI::dbWriteTable(con, "adlb", as.data.frame(pharmaverseadam::adlb))
source("measures/safety.R")
try_measure <- function(name, expr) {
  res <- tryCatch(dplyr::collect(expr), error = function(e) e)
  ok(!inherits(res, "error"),
     paste("measure:", name,
           if (inherits(res, "error")) conditionMessage(res) else ""))
}
try_measure("subjects_by_arm",     subjects_by_arm(con))
try_measure("ae_incidence_by_arm", ae_incidence_by_arm(con, serious = TRUE))
try_measure("teae_by_soc",         teae_by_soc(con))
try_measure("demog_age_by_arm",    demog_age_by_arm(con))
try_measure("disposition_summary", disposition_summary(con))
try_measure("lab_shift_table",     lab_shift_table(con, "ALT"))
DBI::dbDisconnect(con, shutdown = TRUE)

# Bedrock
Sys.setenv(AWS_REGION = "us-east-1")
res <- tryCatch(
  ellmer::chat_aws_bedrock(model = "us.anthropic.claude-sonnet-5")$chat("Say OK"),
  error = function(e) e
)
ok(!inherits(res, "error"), "Bedrock chat smoke test")

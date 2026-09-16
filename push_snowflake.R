# push-to-snowflake.R -- load pharmaverse ADaM datasets into Snowflake
# Run once to set up the warehouse variant of the demo.
#
# Auth: odbc::snowflake() picks up ambient credentials in this order:
#   Workbench-managed Snowflake credentials > SNOWFLAKE_* env vars >
#   ~/.snowflake/connections.toml > browser SSO.
# Requires the Snowflake ODBC driver (preinstalled on Workbench).

library(DBI)
library(odbc)
library(snowflakeauth)
library(admiral)
# ---- 1. Connect -------------------------------------------------------------
con <- DBI::dbConnect(
    odbc::snowflake(),
    database = "CLINICAL_DEMO",
    schema = "ADAM"
)
# ---- 2. Create schema -------------------------------------------------------
dbExecute(con, "CREATE DATABASE IF NOT EXISTS CLINICAL_DEMO")
dbExecute(con, "CREATE SCHEMA IF NOT EXISTS CLINICAL_DEMO.ADAM")
dbExecute(con, "USE SCHEMA CLINICAL_DEMO.ADAM")

# ---- 3. Push the three datasets --------------------------------------------
# as.data.frame() drops tibble/labelled attributes that can confuse drivers.
datasets <- list(
  # ADSL = as.data.frame(pharmaverseadam::adsl),
  # ADAE = as.data.frame(pharmaverseadam::adae),
  # ADLB = as.data.frame(pharmaverseadam::adlb),
  ADTTE = read.csv('adtte.csv')
)

for (nm in names(datasets)) {
  message("Writing ", nm, " (", nrow(datasets[[nm]]), " rows) ...")
  dbWriteTable(con, nm, datasets[[nm]], overwrite = TRUE)
}

# ---- 4. Verify --------------------------------------------------------------
for (nm in names(datasets)) {
  n <- dbGetQuery(con, paste0("SELECT COUNT(*) AS n FROM ", nm))$n
  stopifnot(n == nrow(datasets[[nm]]))
  message(nm, ": ", n, " rows OK")
}

# ---- 5. Read-only access for the agent -------------------------------------
# The agent's connection should NOT use the loader role. Create a read-only
# role once (needs sufficient privileges; otherwise ask your Snowflake admin):
#
# dbExecute(con, "CREATE ROLE IF NOT EXISTS CLINICAL_DEMO_READER")
# dbExecute(con, "GRANT USAGE ON DATABASE CLINICAL_DEMO TO ROLE CLINICAL_DEMO_READER")
# dbExecute(con, "GRANT USAGE ON SCHEMA CLINICAL_DEMO.ADAM TO ROLE CLINICAL_DEMO_READER")
# dbExecute(con, "GRANT SELECT ON ALL TABLES IN SCHEMA CLINICAL_DEMO.ADAM TO ROLE CLINICAL_DEMO_READER")
# dbExecute(con, "GRANT USAGE ON WAREHOUSE DEMO_WH TO ROLE CLINICAL_DEMO_READER")





#create-semantic-view.R
dbExecute(con, "USE SCHEMA CLINICAL_DEMO.ADAM")
 

dbExecute(con, "
CREATE OR REPLACE SEMANTIC VIEW SV_CLINICAL_SAFETY
  TABLES (
    adsl AS CLINICAL_DEMO.ADAM.ADSL
      PRIMARY KEY (USUBJID)
      WITH SYNONYMS ('subjects', 'subject level')
      COMMENT = 'One row per subject: treatment, demographics, disposition',
    adae AS CLINICAL_DEMO.ADAM.ADAE
      PRIMARY KEY (USUBJID, AESEQ)
      WITH SYNONYMS ('adverse events', 'AEs')
      COMMENT = 'One row per adverse event record',
    adtte AS CLINICAL_DEMO.ADAM.ADTTE
      PRIMARY KEY (USUBJID, PARAMCD)
      WITH SYNONYMS ('time to event', 'time to first dermatologic event', 'TTDE')
      COMMENT = 'One row per subject per time-to-event parameter. Currently one parameter: TTDE (time to first dermatologic event), derived from ADAE.'
  )
  RELATIONSHIPS (
    adae_to_adsl AS adae (USUBJID) REFERENCES adsl (USUBJID),
    adtte_to_adsl AS adtte (USUBJID) REFERENCES adsl (USUBJID)
  )
  DIMENSIONS (
    adsl.trt01a   AS TRT01A   COMMENT = 'Actual treatment arm',
    adsl.saffl    AS SAFFL    COMMENT = 'Safety population flag',
    adae.aesoc    AS AESOC    COMMENT = 'MedDRA system organ class',
    adae.aedecod  AS AEDECOD  COMMENT = 'MedDRA preferred term',
    adae.aeser    AS AESER    COMMENT = 'Serious event flag',
    adae.trtemfl  AS TRTEMFL  COMMENT = 'Treatment-emergent flag',
    adtte.paramcd AS PARAMCD  COMMENT = 'Time-to-event parameter code (currently only TTDE)',
    adtte.param   AS PARAM    COMMENT = 'Time-to-event parameter name',
    adtte.trta    AS TRTA     COMMENT = 'Actual treatment arm (ADTTE)',
    adtte.cnsr    AS CNSR     COMMENT = 'Censor flag (1 = censored, 0 = event observed)',
    adtte.evntdesc AS EVNTDESC COMMENT = 'Event or censoring description'
  )
  METRICS (
    adsl.n_subjects AS COUNT(DISTINCT USUBJID)
      COMMENT = 'Number of subjects',
    adae.n_events AS COUNT(AESEQ)
      COMMENT = 'Number of adverse event records',
    adae.n_subjects_with_ae AS COUNT(DISTINCT USUBJID)
      COMMENT = 'Number of subjects with at least one adverse event',
    adtte.n_subjects AS COUNT(DISTINCT USUBJID)
      COMMENT = 'Number of subjects with a time-to-event record',
    adtte.n_events_observed AS COUNT(CASE WHEN CNSR = 0 THEN 1 END)
      COMMENT = 'Number of observed (non-censored) events',
    adtte.avg_aval AS AVG(AVAL)
      COMMENT = 'Average analysis time (AVAL) in days'
  )
  COMMENT = 'Governed safety metrics for the Xanomeline demo study'
")
 
# Verify it exists and is queryable
print(dbGetQuery(con, "SHOW SEMANTIC VIEWS IN SCHEMA CLINICAL_DEMO.ADAM"))
print(dbGetQuery(con, "
  SELECT * FROM SEMANTIC_VIEW(
    SV_CLINICAL_SAFETY
    METRICS adae.n_subjects_with_ae
    DIMENSIONS adsl.trt01a
  )
"))
 
# Grant visibility to the agent's read-only role (commons probes with a
# zero-row query before exposing semantic material):
# dbExecute(con, "GRANT SELECT ON SEMANTIC VIEW SV_CLINICAL_SAFETY TO ROLE CLINICAL_DEMO_READER")
# dbExecute(con, "GRANT REFERENCES ON SEMANTIC VIEW SV_CLINICAL_SAFETY TO ROLE CLINICAL_DEMO_READER")

dbDisconnect(con)

# ---- Agent side (swap into agent.R) ----------------------------------------
# con <- odbc::snowflake(
#   warehouse = "DEMO_WH",
#   database  = "CLINICAL_DEMO",
#   schema    = "ADAM",
#   role      = "CLINICAL_DEMO_READER"   # read-only: the real safety boundary
# )
# trial <- data_source(
#   con,
#   tables     = c("ADSL", "ADAE", "ADLB", "ADTTE"),
#   dictionary = "dictionaries/adam.data-dict.yaml"
# )
# NOTE: Snowflake uppercases unquoted identifiers -- table AND column names
# arrive as ADSL, USUBJID, TRT01A etc. The dplyr measures reference uppercase
# columns already, but update the dictionary/measures table names ("adsl" ->
# "ADSL") for the warehouse variant, or keep two agent.R profiles.
# On Connect, replace this service connection with viewer OAuth credentials
# created inside the Shiny server function.
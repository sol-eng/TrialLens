# agent.R -- constructor for the commons clinical trial agent
# Backend switchable via TRIAL_BACKEND: "snowflake" (default) or "duckdb"
# (self-contained local demo, opt in with TRIAL_BACKEND=duckdb). Uppercase
# table names in both backends so one set of measures and one dictionary
# serves either.

library(commons)
library(ellmer)

Sys.setenv(AWS_REGION = "us-east-1")

make_connection <- function(backend = Sys.getenv("TRIAL_BACKEND", "snowflake")) {
  if (identical(backend, "snowflake")) {
    # On Posit Connect, connectcreds + snowflakeauth must be loaded (never
    # called directly) so the viewer OAuth integration supplies credentials.
    library(connectcreds)
    library(snowflakeauth)

    on_workbench <- Sys.getenv("POSIT_PRODUCT") == "WORKBENCH"
    on_connect   <- Sys.getenv("POSIT_PRODUCT") == "CONNECT"

    if (on_workbench || on_connect) {
      # Workbench: managed Snowflake credentials.
      # Connect: viewer session token via the attached Snowflake integration.
      DBI::dbConnect(
        odbc::snowflake(),
        database = "CLINICAL_DEMO",
        schema   = "ADAM"
      )
    } else {
      # Local fallback: browser SSO
      DBI::dbConnect(
        odbc::snowflake(),
        user          = Sys.getenv("SNOWFLAKE_USER"),
        account       = Sys.getenv("SNOWFLAKE_ACCOUNT"),
        database      = "CLINICAL_DEMO",
        schema        = "ADAM",
        authenticator = "externalbrowser"
      )
    }
  } else {
    con <- DBI::dbConnect(duckdb::duckdb())
    DBI::dbWriteTable(con, "ADSL", as.data.frame(pharmaverseadam::adsl))
    DBI::dbWriteTable(con, "ADAE", as.data.frame(pharmaverseadam::adae))
    DBI::dbWriteTable(con, "ADLB", as.data.frame(pharmaverseadam::adlb))
    # ADTTE is not from pharmaverseadam -- it's the same TTDE (time to first
    # dermatologic event) extract pushed to Snowflake by push_snowflake.R,
    # cached locally so the DuckDB backend matches the warehouse variant.
    DBI::dbWriteTable(con, "ADTTE", read.csv("adtte.csv"))
    con
  }
}

# Disconnects a connection made by make_connection(). DuckDB needs
# shutdown = TRUE to fully release its file lock; Snowflake doesn't. Safe to
# call from session$onSessionEnded(), where errors are otherwise swallowed.
close_connection <- function(con, backend = Sys.getenv("TRIAL_BACKEND", "snowflake")) {
  if (identical(backend, "duckdb")) {
    DBI::dbDisconnect(con, shutdown = TRUE)
  } else {
    DBI::dbDisconnect(con)
  }
}

make_agent <- function(backend = Sys.getenv("TRIAL_BACKEND", "snowflake"),
                        con = make_connection(backend)) {
  trial <- data_source(
    con,
    tables     = c("ADSL", "ADAE", "ADLB", "ADTTE"),
    dictionary = "dictionaries/adam.data-dict.yaml"
  )

  commons(
    client         = chat_aws_bedrock(model = "us.anthropic.claude-sonnet-5"),
    data_sources   = list(trial = trial),
    semantic_layer = semantic_layer("measures/safety.R"),
    context_layer  = context_layer(files = c(
      "context/protocol-excerpt.md",
      "context/sap-conventions.md"
    )),
    instructions   = "instructions.md",
    # Audit loop: full trajectories to OpenTelemetry. On Connect the admin
    # must also enable content observability; without an exporter this is
    # harmless locally. Review in Workbench with trajectory_read()/
    # trajectory_review() -- see trajectory-review.R.
    log = TRUE
  )
}

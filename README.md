# Clinical Trial Q&A Agent (commons demo)

Governed AI agent over CDISC/ADaM trial data, built with
[commons](https://posit-dev.github.io/commons/). Answers from validated
measures get the green **Verified** badge; quotes from the protocol/SAP get
**Cited**; everything else is visibly **Untrusted**.

Data: CDISC Pilot Project study (Study CDISCPILOT01; Xanomeline TTS in
Alzheimer's), 3 arms. `ADSL`/`ADAE`/`ADLB` come from `pharmaverseadam`.
`ADTTE` is a custom time-to-first-dermatologic-event (TTDE) extract (see
`adtte.csv` / `push_snowflake.R`) -- not from `pharmaverseadam`. No real
patient data.

Backend is switchable via `TRIAL_BACKEND`: defaults to `snowflake` (the
warehouse variant, database `CLINICAL_DEMO` / schema `ADAM`); set
`TRIAL_BACKEND=duckdb` for a self-contained local demo that loads the same
four tables into an in-memory DuckDB. See `agent.R`.

## Setup

```r
pak::pak(c(
  "posit-dev/commons/pkg-r", "pharmaverseadam", "duckdb", "odbc",
  "snowflakeauth", "connectcreds", "survival", "ggsurvfit", "ellmer"
))
```

AWS credentials for Bedrock must be available; region is set in `agent.R`
(`us-east-1`). For the Snowflake backend, ambient credentials are picked up
in this order: Workbench-managed Snowflake credentials > `SNOWFLAKE_*` env
vars > `~/.snowflake/connections.toml` > browser SSO (see `push_snowflake.R`
for details, and run it once to (re)populate the warehouse tables and the
semantic view). Then:

```r
source("check-setup.R")   # everything should print OK
shiny::runApp()           # or source("app.R")
```

## Project layout

| File | Role |
|---|---|
| `agent.R` | Connects to Snowflake or DuckDB (`TRIAL_BACKEND`), constructs the agent |
| `app.R` | Runs the chat UI (`commons_server()` + `chat_ui()`), suggestion cards |
| `push_snowflake.R` | One-time loader: pushes ADaM tables + `ADTTE` to Snowflake, creates the semantic view |
| `measures/safety.R` | 9 validated measures (`@measure`) -> Verified answers |
| `dictionaries/adam.data-dict.yaml` | Tables, columns, glossary, governed definitions |
| `context/protocol-excerpt.md` | Study design, AE/SAE definitions -> Cited answers |
| `context/sap-conventions.md` | Populations, TEAE rule, study-day convention |
| `instructions.md` | Agent persona and reporting conventions |
| `check-setup.R` | Pre-demo smoke test (packages, columns, measures, Bedrock) |
| `trajectory-review.R` | Reviews logged agent trajectories (`commons(log = TRUE)`) in Workbench |

## Demo script (rehearse these)

1. **Verified** -- "What proportion of subjects in each arm had a serious
   treatment-emergent adverse event?" -> runs `ae_incidence_by_arm(serious =
   TRUE)`, green badge. Click badge: validated code, model wrote nothing.
2. **Verified** -- "Show me the age distribution by treatment arm." ->
   `demog_age_by_arm()`.
3. **Verified** -- "Plot the Kaplan-Meier curve for time to first
   dermatologic event by treatment arm." -> `km_plot_by_arm()`; a real
   between-arm separation (dermatologic AEs in ~34% of Placebo subjects vs.
   ~73% on Xanomeline), not a fabricated demo curve.
4. **Cited** -- "How is treatment-emergent defined in this study?" -> quotes
   `sap-conventions.md`, blue citation marker.
5. **Untrusted** -- "Do application-site pruritus events cluster in the first
   two weeks of dosing?" -> no measure exists; agent writes custom code in
   its sandbox, yellow badge. Talking point: the validated/exploratory
   boundary your SOPs already draw, enforced in the UI.
6. **Governance close** -- SELECT-only SQL, OS-sandboxed R subprocess, viewer
   OAuth on Connect (Snowflake integration), trajectory logging
   (`commons(log = TRUE)`) reviewed via `trajectory_review()` in Workbench.

Good follow-ups if asked: "Which system organ classes have the most TEAEs on
high dose?" (Verified via `teae_by_soc`), "ALT shift table" (Verified via
`lab_shift_table`), "How many subjects completed?" (`disposition_summary`),
"What's the dermatologic event rate by arm?" (Verified via
`tte_event_rate_by_arm`).

## Known gotchas

- commons is experimental -- pin the working version; rerun `check-setup.R`
  before every customer demo.
- Newer Claude models on Bedrock need the `us.` inference-profile prefix.
- Set `AWS_REGION` **before** the first ellmer call (credentials are cached
  per session).
- If `context_layer("context")` errors on your version, list the two files
  explicitly (see comment in `agent.R`).
- If a `data-dict.yaml` definition fails validation on your version, remove
  it -- the parser only supports simple boolean/comparison expressions, not
  `CASE WHEN`; the dictionary's descriptions still load without it.
- macOS uses the Seatbelt sandbox; don't demo from Windows (no OS sandbox).
- Snowflake uppercases unquoted identifiers -- table and column names arrive
  as `ADSL`, `USUBJID`, `TRT01A`, etc. Measures and the dictionary already
  use uppercase names to match both backends.

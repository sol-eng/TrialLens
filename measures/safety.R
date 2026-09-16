# Validated analysis measures for the clinical trial agent.
# Each function is a "trusted calculation": answers produced by these
# functions carry the green Verified provenance marker.
#
# Conventions (per SAP): safety population (SAFFL = 'Y'); treatment-emergent
# (TRTEMFL = 'Y'); actual treatment arm TRT01A (TRTA in ADLB and ADTTE).
# ADTTE: one row per subject per time-to-event parameter (PARAMCD);
# currently the only parameter is TTDE (time to first dermatologic event,
# derived from ADAE). CNSR = 0 means the event was observed, CNSR = 1
# means the subject was censored (no dermatologic AE by study completion).

#' Number of subjects by treatment arm
#'
#' Counts safety-population subjects in each actual treatment arm (TRT01A).
#'
#' @measure
subjects_by_arm <- function(trial) {
  dplyr::tbl(trial, "ADSL") |>
    dplyr::filter(SAFFL == "Y") |>
    dplyr::count(TRT01A, name = "n_subjects") |>
    dplyr::arrange(TRT01A)
}

#' Incidence of treatment-emergent adverse events by arm
#'
#' Number and percentage of safety-population subjects with at least one
#' treatment-emergent adverse event (TEAE), by actual treatment arm.
#'
#' @param serious `logical` If `TRUE`, restrict to serious adverse events
#'   (AESER = 'Y'). Defaults to `FALSE` (all TEAEs).
#' @measure
ae_incidence_by_arm <- function(trial, serious = FALSE) {
  denom <- dplyr::tbl(trial, "ADSL") |>
    dplyr::filter(SAFFL == "Y") |>
    dplyr::count(TRT01A, name = "N")

  events <- dplyr::tbl(trial, "ADAE") |>
    dplyr::filter(TRTEMFL == "Y", SAFFL == "Y")
  if (isTRUE(serious)) {
    events <- dplyr::filter(events, AESER == "Y")
  }

  num <- events |>
    dplyr::distinct(TRT01A, USUBJID) |>
    dplyr::count(TRT01A, name = "n_subjects")

  denom |>
    dplyr::left_join(num, by = "TRT01A") |>
    dplyr::mutate(
      n_subjects = dplyr::coalesce(n_subjects, 0L),
      pct = round(100 * n_subjects / N, 1)
    ) |>
    dplyr::select(TRT01A, n_subjects, N, pct) |>
    dplyr::arrange(TRT01A)
}

#' Treatment-emergent adverse events by system organ class
#'
#' Number of events and number of subjects with at least one TEAE, grouped
#' by primary system organ class (AESOC) and actual treatment arm. Safety
#' population.
#'
#' @param arm `string` Optional actual treatment arm (TRT01A value) to
#'   restrict to, e.g. "Placebo". Defaults to all arms.
#' @measure
teae_by_soc <- function(trial, arm = NULL) {
  aes <- dplyr::tbl(trial, "ADAE") |>
    dplyr::filter(TRTEMFL == "Y", SAFFL == "Y")
  if (!is.null(arm)) {
    valid_arms <- aes |> dplyr::distinct(TRT01A) |> dplyr::pull(TRT01A)
    if (!arm %in% valid_arms) {
      stop(
        "Unknown treatment arm '", arm, "'. Valid arms: ",
        paste(sort(valid_arms), collapse = ", "),
        call. = FALSE
      )
    }
    aes <- dplyr::filter(aes, TRT01A == arm)
  }
  aes |>
    dplyr::group_by(TRT01A, AESOC) |>
    dplyr::summarize(
      n_events   = dplyr::n(),
      n_subjects = dplyr::n_distinct(USUBJID),
      .groups = "drop"
    ) |>
    dplyr::arrange(TRT01A, dplyr::desc(n_subjects))
}

#' Age distribution by treatment arm
#'
#' Age summary and distribution: descriptive statistics for age (years) --
#' n, mean, SD, median, min, max -- among safety-population subjects, by
#' actual treatment arm. Use for any question about subject age, age
#' distribution, average or median age, or age demographics by arm.
#' Standard Table 1 demographics component.
#'
#' @measure
demog_age_by_arm <- function(trial) {
  dplyr::tbl(trial, "ADSL") |>
    dplyr::filter(SAFFL == "Y") |>
    dplyr::group_by(TRT01A) |>
    dplyr::summarize(
      n          = dplyr::n(),
      mean_age   = round(mean(AGE, na.rm = TRUE), 1),
      sd_age     = round(sd(AGE, na.rm = TRUE), 2),
      median_age = median(AGE, na.rm = TRUE),
      min_age    = min(AGE, na.rm = TRUE),
      max_age    = max(AGE, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::arrange(TRT01A)
}

#' Subject disposition by treatment arm
#'
#' End-of-study status (EOSSTT) counts by actual treatment arm, safety
#' population.
#'
#' @measure
disposition_summary <- function(trial) {
  dplyr::tbl(trial, "ADSL") |>
    dplyr::filter(SAFFL == "Y") |>
    dplyr::count(TRT01A, EOSSTT, name = "n_subjects") |>
    dplyr::arrange(TRT01A, EOSSTT)
}

#' Laboratory shift table for a parameter
#'
#' Counts of on-treatment lab records by baseline reference-range indicator
#' (BNRIND) versus analysis reference-range indicator (ANRIND), by actual
#' treatment (TRTA). Safety population, on-treatment records only.
#'
#' @param param `string` Lab parameter code (PARAMCD), e.g. "ALT", "AST",
#'   "BILI", "CREAT", "HGB", "PLAT", "WBC", "SODIUM", "POTAS", "GLUC".
#' @measure
lab_shift_table <- function(trial, param) {
  adlb <- dplyr::tbl(trial, "ADLB")

  valid_params <- adlb |> dplyr::distinct(PARAMCD) |> dplyr::pull(PARAMCD)
  if (!param %in% valid_params) {
    stop(
      "Unknown lab parameter code '", param, "'. Valid codes: ",
      paste(sort(valid_params), collapse = ", "),
      call. = FALSE
    )
  }

  adlb |>
    dplyr::filter(
      PARAMCD == param,
      ONTRTFL == "Y",
      SAFFL == "Y",
      !is.na(BNRIND),
      !is.na(ANRIND)
    ) |>
    dplyr::count(TRTA, BNRIND, ANRIND, name = "n_records") |>
    dplyr::arrange(TRTA, BNRIND, ANRIND)
}

#' Time-to-event subject counts by arm and parameter
#'
#' Number of subjects with a time-to-event record (ADTTE), by actual
#' treatment arm (TRTA) and parameter code (PARAMCD; currently only
#' "TTDE", time to first dermatologic event).
#'
#' @measure
tte_subjects_by_arm <- function(trial) {
  dplyr::tbl(trial, "ADTTE") |>
    dplyr::count(TRTA, PARAMCD, name = "n_subjects") |>
    dplyr::arrange(PARAMCD, TRTA)
}

#' Time-to-event event rate by arm and parameter
#'
#' Number and percentage of subjects with an observed (non-censored) event
#' -- CNSR = 0 -- versus the total number of subjects with a record, by
#' actual treatment arm (TRTA) and time-to-event parameter (PARAMCD). Use
#' for questions about dermatologic event rates or time-to-first-event
#' censoring (TTDE, time to first dermatologic event).
#'
#' @param param `string` Optional time-to-event parameter code (PARAMCD).
#'   Defaults to all parameters (currently only "TTDE").
#' @measure
tte_event_rate_by_arm <- function(trial, param = NULL) {
  adtte <- dplyr::tbl(trial, "ADTTE")

  if (!is.null(param)) {
    valid_params <- adtte |> dplyr::distinct(PARAMCD) |> dplyr::pull(PARAMCD)
    if (!param %in% valid_params) {
      stop(
        "Unknown time-to-event parameter code '", param, "'. Valid codes: ",
        paste(sort(valid_params), collapse = ", "),
        call. = FALSE
      )
    }
    adtte <- dplyr::filter(adtte, PARAMCD == param)
  }

  adtte |>
    dplyr::group_by(PARAMCD, TRTA) |>
    dplyr::summarize(
      n_subjects = dplyr::n(),
      # sum(CNSR == 0) is boolean and not portable across SQL backends
      # (Snowflake rejects SUM(BOOLEAN)); cast to integer first.
      n_events   = sum(as.integer(CNSR == 0), na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(pct_events = round(100 * n_events / n_subjects, 1)) |>
    dplyr::arrange(PARAMCD, TRTA)
}

#' Kaplan-Meier survival plot by treatment arm
#'
#' Publication-style Kaplan-Meier curve for a time-to-event parameter
#' (PARAMCD), stratified by actual treatment arm (TRTA), with a pointwise
#' confidence band and an at-risk table. Returns a ggplot2 object -- use
#' for any request to plot, chart, or visualize time to first dermatologic
#' event (TTDE) or other time-to-event endpoints.
#' Built with ggsurvfit on top of survival::survfit2().
#'
#' @param param `string` Time-to-event parameter code (PARAMCD). Defaults
#'   to "TTDE" (time to first dermatologic event), currently the only
#'   parameter in ADTTE.
#' @measure
km_plot_by_arm <- function(trial, param = "TTDE") {
  adtte <- dplyr::tbl(trial, "ADTTE")

  valid_params <- adtte |> dplyr::distinct(PARAMCD) |> dplyr::pull(PARAMCD)
  if (!param %in% valid_params) {
    stop(
      "Unknown time-to-event parameter code '", param, "'. Valid codes: ",
      paste(sort(valid_params), collapse = ", "),
      call. = FALSE
    )
  }

  raw <- adtte |>
    dplyr::filter(PARAMCD == param) |>
    dplyr::select(TRTA, AVAL, CNSR, PARAM) |>
    dplyr::collect()

  param_label <- raw$PARAM[[1]]
  # Drop PARAM/PARAMCD before fitting -- ggsurvfit's model.frame handling
  # otherwise warns about non-unique columns.
  df <- data.frame(
    TRTA = factor(
      raw$TRTA,
      levels = c("Placebo", "Xanomeline Low Dose", "Xanomeline High Dose")
    ),
    AVAL = raw$AVAL,
    CNSR = raw$CNSR
  )

  ggsurvfit::survfit2(survival::Surv(AVAL, 1 - CNSR) ~ TRTA, data = df) |>
    ggsurvfit::ggsurvfit(linewidth = 0.8) +
    ggsurvfit::add_confidence_interval() +
    ggsurvfit::add_risktable(risktable_stats = "n.risk") +
    ggplot2::labs(
      title = paste0("Kaplan-Meier estimate: ", param_label),
      subtitle = "Safety population, by actual treatment arm",
      x = "Time (days)", y = "Event-free probability",
      color = NULL, fill = NULL
    ) +
    ggsurvfit::theme_ggsurvfit_default()
}

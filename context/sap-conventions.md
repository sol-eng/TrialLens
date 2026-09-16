# Statistical analysis plan conventions (demo study)

> SAP excerpt for demonstration purposes.

## Analysis populations

The **safety population** comprises all randomized subjects who received at
least one dose of study treatment. It is identified by SAFFL = 'Y' in ADSL
and is the analysis population for all safety summaries. Subjects are
summarized according to the treatment they actually received (TRT01A).

## Treatment-emergent adverse events

A **treatment-emergent adverse event (TEAE)** is an adverse event with
onset on or after the date of first dose of study treatment, or a
pre-existing condition that worsens in severity after the first dose.
TEAEs are identified by TRTEMFL = 'Y' in ADAE. All adverse event summary
tables include treatment-emergent events only, unless otherwise specified.

## Adverse event summaries

Adverse events are coded with MedDRA and summarized by primary system
organ class (AESOC) and preferred term (AEDECOD). Subject-level incidence
counts each subject at most once within a system organ class or preferred
term, at the maximum severity. Percentages use the number of
safety-population subjects in the arm as the denominator.

## Study day convention

Study day (ASTDY, ADY) is calculated relative to the date of first dose.
Day 1 is the first day of treatment; the day before is Day -1. There is
no Day 0. "Within the first two weeks of treatment" therefore corresponds
to study days 1 through 14 inclusive.

## Laboratory analyses

Laboratory results are summarized in standard units. Shift tables
cross-tabulate the baseline reference-range indicator (BNRIND) against the
analysis reference-range indicator (ANRIND) for on-treatment records
(ONTRTFL = 'Y'). Toxicity grading follows CTCAE-style criteria captured in
ATOXGR. Liver safety monitoring focuses on ALT, AST, and total bilirubin
(PARAMCD values ALT, AST, BILI).

## Exploratory analyses

Any analysis not pre-specified in this plan is exploratory. Exploratory
results require review by the study statistician before inclusion in any
regulatory document or external communication.

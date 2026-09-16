# app.R -- TrialLens: governed clinical trial Q&A agent (multi-user)
library(shiny)
library(bslib)
library(shinychat)
library(commons)
library(ggplot2)
library(ggsurvfit)
library(paws.common)
# Backend defaults to "snowflake" (warehouse variant); set TRIAL_BACKEND=duckdb
# as an env var (e.g. on the Connect content item, or locally) to use the
# self-contained laptop demo instead. The default lives in agent.R so it's
# consistent whether make_agent() is called from this app or elsewhere.
source("agent.R")   # defines make_agent(); nothing heavy runs at load time

greeting <- paste(
  "**Welcome to TrialLens.** Ask me anything about study CDISCPILOT01",
  "(Xanomeline TTS in Alzheimer's disease, from the public CDISC Pilot",
  "Project).\n\n",
  "Every answer carries a provenance marker:\n\n",
  "- **Verified** (green): I ran a validated calculation authored by the",
  "study's statisticians, no AI-written code.\n",
  "- **Cited** (blue): my answer quotes the protocol or SAP, and the quote",
  "was verified against the source.\n",
  "- **Untrusted** (yellow): I wrote exploratory code myself. Treat the",
  "result as a draft for biostatistics review.\n\n",
  "Try a suggestion above, or ask your own question."
)

# Suggestion cards: label, question, expected provenance. Badge is always
# one of the three categories the greeting defines (Verified/Cited/
# Untrusted) so the cards preview the same color code used on real answers --
# including the one question that ends up Untrusted because it calls for
# exploratory code no trusted calculation covers.
suggestions <- list(
  list(label = "Serious TEAEs by arm",
       question = "What proportion of subjects in each arm had a serious treatment-emergent adverse event?",
       badge = "Verified"),
  list(label = "Age by treatment arm",
       question = "Summarize age by treatment arm.",
       badge = "Verified"),
  list(label = "TEAE definition",
       question = "How is 'treatment-emergent' defined in this study?",
       badge = "Cited"),
  list(label = "Early pruritus events",
       question = "Do application-site pruritus events cluster in the first two weeks of dosing?",
       badge = "Untrusted"),
  list(label = "Dermatologic event survival plot",
       question = "Plot the Kaplan-Meier curve for time to first dermatologic event by treatment arm.",
       badge = "Verified")
)

# Badge classes mirror the provenance colors described in the greeting:
# Verified = green, Cited = blue, Untrusted = yellow.
badge_class <- function(badge) {
  switch(badge,
    Verified  = "badge bg-success-subtle text-success-emphasis mt-1",
    Cited     = "badge bg-info-subtle text-info-emphasis mt-1",
    Untrusted = "badge bg-warning-subtle text-warning-emphasis mt-1",
    "badge bg-light text-secondary mt-1"
  )
}

suggestion_card <- function(i, s) {
  card(
    class = "suggestion-card",
    style = "cursor: pointer;",
    card_body(
      padding = "0.7rem",
      actionLink(
        paste0("suggest_", i),
        label = div(
          div(s$label, style = "font-weight: 600; font-size: 0.9rem;"),
          div(s$question, class = "card-question",
              style = "font-size: 0.72rem; color: var(--bs-secondary-color);"),
          span(s$badge, class = badge_class(s$badge))
        ),
        style = "text-decoration: none; color: inherit;"
      )
    )
  )
}

suggestion_card_style <- tags$style(HTML("
  .suggestion-card {
    transition: box-shadow 0.15s ease, transform 0.15s ease;
  }
  .suggestion-card:hover, .suggestion-card:focus-within {
    box-shadow: 0 0.25rem 0.75rem rgba(0, 0, 0, 0.08);
    transform: translateY(-1px);
  }
  .suggestion-card .card-question {
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
    min-height: 2.2em;
  }
"))

ui <- page_fillable(
  title = "TrialLens",
  theme = commons_theme(),
  tags$head(
    tags$link(rel = "icon", type = "image/svg+xml", href = "logo.svg")
  ),
  suggestion_card_style,
  div(
    style = "padding: 0.25rem 0 0.5rem 0; display: flex; align-items: center; gap: 0.5rem;",
    tags$img(src = "logo.svg", height = "32px", width = "32px", alt = "TrialLens logo"),
    div(
      h3("TrialLens", style = "margin-bottom: 0.1rem;"),
      div("CDISC pilot study",
          style = "color: var(--bs-secondary-color); font-size: 0.85rem;")
    )
  ),
  layout_column_wrap(
    width = 1 / 5, gap = "0.5rem", fill = FALSE,
    !!!Map(suggestion_card, seq_along(suggestions), suggestions)
  ),
  chat_ui("chat", height = "100%")
)

server <- function(input, output, session) {
  # MULTI-USER: one agent per session -- isolated chat state, own database
  # connection (viewer OAuth on Connect), own sandboxed R subprocess. Hold
  # `con` here (rather than inside make_agent()) so it can be closed when
  # the session ends instead of leaking until GC/process restart.
  con   <- make_connection()
  agent <- make_agent(con = con)
  session$onSessionEnded(function() {
    try(close_connection(con), silent = TRUE)
  })
  commons_server("chat", agent)

  # Welcome message explaining the provenance badges
  chat_set_greeting("chat", greeting)
  # If your shinychat predates chat_set_greeting(), use instead:
  # chat_append("chat", greeting)

  lapply(seq_along(suggestions), function(i) {
    observeEvent(input[[paste0("suggest_", i)]], {
      update_chat_user_input("chat", value = suggestions[[i]]$question,
                             submit = TRUE)
    })
  })
}

shinyApp(ui, server)
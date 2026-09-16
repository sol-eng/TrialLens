# trajectory-review.R -- the audit/review demo beat (run in Workbench)
#
# Prereqs for trajectories to flow on Connect:
#   1. Connect admin: enable OpenTelemetry + content instrumentation
#   2. This app: commons(log = TRUE)  (already set in agent.R)
#   3. Content observability activates after the content process restarts
# You must be owner or collaborator on the deployed content item.

library(commons)

# The deployed app's content GUID (Connect dashboard > Info panel)
content_guid <- Sys.getenv("TRIALLENS_GUID", "208cb22c-6cde-4b30-a0fe-5d74b819a956")


# Option 1: env vars (put in ~/.Renviron for persistence -- never commit
# real values here). CONNECT_SERVER / CONNECT_API_KEY are read from the
# environment; set them in ~/.Renviron as:
#   CONNECT_SERVER=https://pct.demo.soleng.posit.it
#   CONNECT_API_KEY=...   # Connect > your profile > API Keys
if (!nzchar(Sys.getenv("CONNECT_SERVER")) || !nzchar(Sys.getenv("CONNECT_API_KEY"))) {
  stop(
    "CONNECT_SERVER and/or CONNECT_API_KEY are not set. Add them to ",
    "~/.Renviron (never hardcode credentials in this script) and restart R."
  )
}


# ---- 1. Pull recent conversations ------------------------------------------
trajectories <- trajectory_read(content_guid)
print(trajectories)

# ---- 2. Interactive review ---------------------------------------------------
# Opens the reviewer: step through conversations, see every tool call the
# agent made (which measure ran, what SQL/R it wrote), flag or annotate.
# Flagged/annotated conversations are written as Markdown review documents --
# store those only in an appropriately protected location.
trajectory_review(trajectories)

# ---- Demo talk track ---------------------------------------------------------
# "Yesterday a medical monitor asked whether application-site pruritus
#  clusters early. The agent wrote exploratory code, and the answer was
#  flagged Untrusted. Here is the statistician reviewing exactly what the
#  agent did -- the question, the code it wrote, the result. If this
#  question keeps coming up, the team promotes it into a validated measure,
#  and from then on it's a green Verified answer. Untrusted questions are
#  not a failure mode -- they're next quarter's validated backlog."

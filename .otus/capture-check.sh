#!/bin/sh
# OTUS capture — SessionStart check. This is what makes capture ON BY DEFAULT.
#
# Capture used to be "on by default" only in the copy. In practice it was off in
# every repo, because turning it on required the student to know that
# /otus-verify-connection exists and to type it. Nothing ever said so.
#
# This hook closes that gap. It runs at SessionStart, where Claude Code adds a
# hook's plain-text stdout to the agent's context — one of only three events
# that do (SessionStart, UserPromptSubmit, UserPromptExpansion). The Stop hook
# deliberately does NOT do this work: Stop stdout is written to the debug log,
# not surfaced, which is why the capture device flow is driven by the skill and
# not by .otus/capture.sh (see the copy canon, amendment A3).
#
# Codex has no equivalent wired event here, so AGENTS.md carries the same
# instruction in prose for that agent.
#
# THREE RULES, all of them about not being obnoxious:
#   1. SILENT when there is nothing to do. Capture already configured, student
#      already declined, repo not provisioned -> print nothing at all. This text
#      enters the context of every session, so it must earn its place.
#   2. NEVER FAILS. A session must never break because of capture. No `set -e`
#      (`[ -f x ] && exit 0` exits 1 under it when the test fails), every path
#      ends `exit 0`.
#   3. NEVER TOUCHES THE TOKEN. It tests whether the file is non-empty; it does
#      not read, print, or transmit it. Everything printed here lands in the
#      transcript, and the transcript is uploaded to OTUS.
set -u

# Not an OTUS deliverable repo (or not provisioned) — say nothing.
if [ ! -f ".otus/deliverable.json" ]; then
  exit 0
fi

# Already configured, either way round. Nothing to ask.
if [ -n "${OTUS_CAPTURE_TOKEN:-}" ]; then
  exit 0
fi
if [ -s ".otus/capture-token" ]; then
  exit 0
fi

# The student said no. Consent means the answer sticks — don't ask again until
# they remove this file (or run the skill themselves).
if [ -f ".otus/capture-declined" ]; then
  exit 0
fi

# Provisioning never finished, so the approval flow would refuse to run anyway.
# Not the student's problem to fix and not worth opening a session on.
iteration_id="$(sed -n 's/.*"iteration_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' .otus/deliverable.json 2>/dev/null || true)"
case "${iteration_id:-}" in
  "" | "<iteration_id>") exit 0 ;;
esac

cat <<'EOF'
[OTUS] Transcript capture is not turned on in this repository yet.

Capture is on by default for this course: OTUS observes your agent sessions in
this repo so your work is reflected on the deliverable page. It is feedback
only — it never gates completion and is not graded.

Before starting other work, direct the student to /otus-verify-connection. That
skill always begins with OTUS's fixed disclosure and does nothing until the
student replies exactly "I agree". It then checks identity, push access, hook
wiring, and capture enablement and drives the one-click browser approval when
needed. There is no token to copy or paste.

If the student declines, the skill records that choice so this prompt stays
quiet. Never print, read back, or commit a capture token.
EOF

exit 0

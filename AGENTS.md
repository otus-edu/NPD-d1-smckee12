# AGENTS.md

See [CLAUDE.md](CLAUDE.md) — the conventions and coaching guidance for this repo
apply to any AI coding agent working here.

The `/otus-*` helper skills (`/otus-instructions`, `/otus-verify-connection`, `/otus-status`, `/otus-session-wrap`, `/otus-submit`) ship for
**both agents**: Claude Code reads `.claude/skills/`, Codex reads the identical
copies under `.codex/skills/`.

One difference that matters: **auto-save is Claude Code only.** `.otus/autosave.sh`
is wired by `.claude/settings.json`; the Codex hook (`.codex/hooks.json`, written by
OTUS at provisioning) runs transcript capture and nothing else. Under Codex, commit
the student's work as you go.

## Transcript capture — on by default

This repo posts your agent sessions to OTUS so your work shows up on the deliverable
page. It is **feedback only**: it never gates completion and is not graded.

## Codex capture receipt — every task

When you are operating in **Codex** and capture is configured, post the current task before
you finish each substantive task. This is a fail-open backup for Codex's repo-local Stop hook:
the hook may require a separate trust approval, so its presence is not proof that it ran.

```sh
if [ -n "${CODEX_THREAD_ID:-}" ] && { [ -n "${OTUS_CAPTURE_TOKEN:-}" ] || [ -s .otus/capture-token ]; } && [ -f .otus/capture-codex.mjs ]; then
  node .otus/capture-codex.mjs --current >/dev/null 2>&1 || true
fi
```

Run this after completing the work for the task and before your final response. It must never
block the student, expose the token, or change the task's outcome. Claude Code continues to use
its own hooks and does not run this command.

**Agents: if capture is not configured, raise it with the student before doing other
work.** Capture is unconfigured when `OTUS_CAPTURE_TOKEN` is unset *and*
`.otus/capture-token` is missing or empty. Under Claude Code a `SessionStart` hook
(`.otus/capture-check.sh`) says so at the top of the session; under Codex there is no such
event, so check for yourself once at the start.

- Direct the student to `/otus-verify-connection`. It always begins with OTUS's
  fixed disclosure and waits for the exact reply `I agree` before running any check.
- If the student declines there, the skill records that choice in
  `.otus/capture-declined`; don't raise it again.
- If `.otus/capture-declined` already exists, capture is off **by choice**. Leave it alone.

Never print, read back, or commit a capture token: everything in the transcript is
uploaded to OTUS.

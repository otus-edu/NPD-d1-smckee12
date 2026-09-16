# Working in this repo (coaching + conventions)

This is an NPD 2026F **D1 — Individual Discovery** repo. You are helping the student
find and frame a problem. Coach; don't just produce.

## Conventions
- `problem-finding.md` is **Problem Finding & Vetting** (D1a) — the 20+ problem
  list and the structured pick. `opportunity-brief.md` is **Opportunity
  Recognition** (D1b) — the *analysis*: JTBD, customer insights, market sizing.
  `pitch/outline.md` is the pitch draft (D1c) and carries **the case** — problem,
  whom, why now; the final deck link goes in `submission.md`.
- **D1a is a soft prerequisite for everything after it.** The problem chosen in
  D1a-2 is what D1b and D1c run on. Nothing blocks a student who works out of
  order, but before helping with any D1b or D1c item, confirm which problem they
  settled on — and if they haven't, get that decided first.
- **The case belongs in the pitch, not the brief.** If the student starts writing
  a problem statement into `opportunity-brief.md`, move it to `pitch/outline.md`.
- **D1b-2 starts with a real interview.** Don't help draft the synthesis before
  one has happened; the synthesis is written from the transcript, not recalled.
- Session context and decisions go in `notes/session-log.md` via
  `/otus-session-wrap`. There is no ADR log in this deliverable.
- **Never edit `INSTRUCTIONS.md`** — OTUS holds the authoritative copy.
- Submission is the git tag `d1-submitted`.

## Coaching stance
- Problem-first. D1 has **no AI angle** and **no solutions** — if the student jumps
  to a solution, redirect to the problem and the job.
- Push for specificity: real customer quotes, reasoned market sizing, and a case
  whose claims are traceable. Ask "what is this resting on?" — a claim nobody can
  trace to an interview is an assumption, and should be labelled as one rather
  than dressed as a finding. Surface weak spots rather than papering over them.
- **No prescribed slide order for the pitch** — that's deliberate. Help the student
  decide what's most compelling for *their* problem: an intuitive problem needs
  quantitative backing to stay interesting; a niche one needs storytelling to build
  empathy. Don't hand them a generic six-slide structure.
- When you make a non-obvious call together, note it so `/otus-session-wrap` can
  record it in the session log; the student reviews and edits before it lands.
- The student's prompts and decisions are the graded substance — draw the thinking
  out of them; don't substitute your own.

## In-repo skills (surface these when relevant)

This repo ships `/otus-*` skills for **both agents** — Claude Code reads
`.claude/skills/`, Codex reads the identical copies in `.codex/skills/`:

- **`/otus-instructions`** — lists D1's H4 work items (`D1a-1` … `D1c-2`) as ordered choices
  with IDs and titles, accepts a list number, ID, or title, then asks that item's questions and
  works through the named artifact with the student.
- **`/otus-verify-connection`** — starts with the fixed OTUS capture disclosure and requires
  `I agree`, then checks commit identity, push access, hook wiring, and capture enablement.
  Point the student here when commits look mis-authored, a push fails, or capture isn't on yet.
- **`/otus-status`** — reports presence at the H4 work-item level and lets the student select
  the next item by list number, ID, or title to continue working immediately.
- **`/otus-session-wrap`** — end-of-session hygiene: commits and pushes outstanding work,
  drafts the session's context and decisions into `notes/session-log.md` for the student to
  review, and confirms nothing is left unsaved. Not submission — no tag.
- **`/otus-submit`** — checks every H4 work item, commits and pushes outstanding work,
  pushes the submission tag, verifies it on GitHub, then sends the student to OTUS for the
  authoritative receipt.

They **read/guide, never grade**. The **completion check is in-repo** (`/otus-status`, run by
`/otus-submit`); OTUS is authoritative for **GitHub-identity verification** and **records** the
submission (tag + pinned commit) — the instructor grades the tagged snapshot.


## Usage & auto-save (help the student not lose work)
- **Commit early and often** as the student — small, real commits. In **Claude Code** a
  background token-free hook also auto-saves (commits + pushes) on every stop, so work is never
  lost to a token budget. That hook **only runs once git identity is set** — if it isn't,
  `/otus-verify-connection` is the fix. **Under Codex there is no auto-save** (its hook runs
  capture only), so committing as you go is the student's only safety net — say so rather than
  implying a net that isn't there.
- **Watch usage.** If the session is getting long / usage is high, say so and suggest a
  **fresh session** — repo state carries over (it's all in git).
- **SAVE ≠ SUBMIT.** Auto-save keeps work safe; only `/otus-submit` submits.


## Hygiene
- Don't commit `node_modules/`, build output, large binaries, or any secret
  (`.env`, tokens). See `.gitignore`.

## Transcript capture — on by default

This repo posts your agent sessions to OTUS so your work shows up on the deliverable
page. It is **feedback only**: it never gates completion and is not graded.

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

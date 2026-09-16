---
name: otus-session-wrap
description: >-
  Close out a working session on this deliverable cleanly. Invoke when the student or team types
  /otus-session-wrap, says they are stopping for now, wants to wrap up, asks to save their work
  before closing, or is about to close the agent. Commits and pushes outstanding work under a real
  identity, writes the session's context and decisions into notes/ so the next session starts warm,
  and confirms in plain terms that nothing is left unsaved. This is NOT submission — it does not
  create or push a submission tag; /otus-submit does that.
---

# /otus-session-wrap — save the work, record the thinking, confirm it is safe to close

A session ends in one of two states: everything is on GitHub and the next session can pick up where
this one stopped, or it is not. This skill makes it the first one.

**This is not submission.** No tag is created here. A student can wrap a session many times before
running `/otus-submit` once.

Use ordered lists for all student-facing checks, choices, and next actions. Never use lettered
menus.

## 1. Commit outstanding work

Before creating any commit:

```sh
git config user.name
git config user.email
```

1. Stop if either value is unset, uses the OTUS bot identity, or is obviously shared/team-generic.
   Help set the student's own identity, then re-check it. Credit is assigned by commit author.
2. Inspect `git status --porcelain` and the diff.
3. Exclude secrets, capture tokens/device files, `.env`, dependencies, build output, and large
   binaries.
4. Commit related outstanding work with an accurate message. Split clearly unrelated changes.
5. If the tree is already clean, say so and continue. Never create an empty commit.
6. Push with `git push origin HEAD`. If the push fails, stop and troubleshoot — uncommitted or
   unpushed work is exactly what this skill exists to prevent.

## 2. Record the session's context and decisions

Write to `notes/session-log.md`, creating it if it does not exist. Append one dated entry per
session; never rewrite an earlier entry.

Draft the entry from what actually happened in this session, then **hand it back for review before
writing it**. The student edits and accepts it — the curation is the point, and an entry they did
not read is worth nothing to them next week.

Each entry covers, in whatever length the session earns:

1. **What moved** — which work items were advanced, and how far.
2. **Decisions made, and why** — the calls that would be expensive to re-litigate. Include the
   alternatives that were weighed and passed over. If a decision was made and then reversed, say
   so; the reversal is usually the useful part.
3. **Open threads** — what is unresolved, what the student was in the middle of, what they said
   they would do next.
4. **Anything that surprised them** — a result that contradicted an assumption is the most
   valuable thing to carry forward.

Never invent a decision that was not made. An honest short entry beats a padded one.

## 3. Confirm it is safe to close

Verify before claiming it, and show the evidence:

```sh
git status --porcelain
git log origin/HEAD..HEAD --oneline
```

Both must come back empty. Then report exactly this shape:

1. "Everything is committed and pushed — GitHub has your work at `<short-sha>`."
2. "This session's context is written to `notes/session-log.md`."
3. "Nothing is left only on this machine. It is safe to close."

If either check is not empty, say plainly what is still outstanding and do not tell the student it
is safe to close.

## Boundaries

1. Wrap a session; never submit one. No tags.
2. Never grade, and never assess whether the work is good enough.
3. Never invent decisions the student did not make.
4. Never write the session log without the student reviewing it first.
5. Never expose or commit secrets or capture credentials.
6. Never claim the work is safe when the verification commands say otherwise.

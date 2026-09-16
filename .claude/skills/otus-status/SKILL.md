---
name: otus-status
description: >-
  Show where the student stands at the actionable H4 work-item level and guide them into the most
  useful next item. Invoke when the student types /otus-status, asks where they are, whether they
  are done, what's missing, or what to do next. Reports presence rather than quality, uses ordered
  choices with each item's ID and title, and accepts a follow-on selection by list number, ID, or
  title. Never exposes internal manifest or detector terminology.
---

# /otus-status — H4 progress and the next useful action

Check the deliverable at the same H4 work-item granularity used by `/otus-instructions`. A parent
such as D1a is not complete merely because one of D1a's children has content.

This is **presence, never quality**. A thin but genuine response passes. The instructor, not this
skill, evaluates quality.

## 1. Load the work items

Read `INSTRUCTIONS.md` and `.otus/manifest.json` when present. These are implementation sources;
do not name them, the manifest, detectors, schemas, or parsing in student-facing output.

Build the ordered list:

1. Use `work_items` when present, preserving array order.
2. Otherwise derive one item from each actionable H4 under `## Deliverable Instructions`.
3. Use each H4's ID, title, Expected Outcome, Requirements, named artifact, and parent context.
4. If the brief has no H4 items, use its shallowest actionable headings.

The optional generic work-item contract is:

1. `id`, `title`, `path`, and optional `sections`.
2. `complete_when` for presence-oriented evidence.
3. `coach` for the follow-on guidance flow.

## 2. Establish the shipped baseline

Use the repository's first commit as the shipped state:

```sh
root=$(git rev-list --max-parents=0 HEAD | tail -1)
git diff --stat "$root" -- .
```

Read current artifacts and, when necessary, their root-commit versions. Never treat a seeded
placeholder as completed work.

## 3. Check each H4 item independently

For every work item, decide **complete / not yet** and give one short, concrete reason.

1. When `complete_when` exists, check every listed condition in the item's named sections or
   artifact.
2. Otherwise, check that the H4's required evidence is present and differs from its shipped
   placeholder.
3. When several H4 items share one file, inspect only the section or fields belonging to each item.
   One edit elsewhere in the file must not complete all of them.
4. For a questionnaire, each required answer in the item's section must be replaced; a remaining
   placeholder makes that item incomplete.
5. For a paragraph, table, analysis, or living document, check that the requested artifact or
   section has genuine student content. Do not evaluate whether it is persuasive or correct.
6. For a link or prototype item, check that the required destination contains a real URL or link.
7. For an item whose evidence cannot be reliably separated from a shared artifact, say what can and
   cannot be confirmed; do not guess.

Also inspect:

1. Uncommitted work with `git status --porcelain`.
2. Whether any non-bot commit exists.
3. The submission tag from `.otus/deliverable.json` / the deliverable key.

Submission is a separate state, not an H4 work item and not part of the content-completion
denominator.

## 4. Report with ordered, titled work items

Use an ordered list in instruction order. Every line includes list position, status, ID, title,
and a short evidence statement:

```text
/otus-status — Onboarding Questionnaire · instructions v6

1. ✓ D0a-1 — Who You Are — all three responses are filled in
2. ✓ D0a-2 — Your Background — all five responses are filled in
3. ✗ D0a-3 — This Course — product and support responses are still placeholders

2 of 3 work items complete.
Submission: not submitted — d0-submitted is not on this repo.
Working tree: 1 uncommitted file.

Next choices:
1. D0a-3 — This Course
2. Run /otus-submit after all work items are complete

Choose 1, "D0a-3", or "This Course".
```

Use ordered lists for all choices, requirements, progress, and next actions. Do not use bullets or
lettered menus.

Prioritize unfinished work with nothing started. If every item has begun, choose the first
incomplete item in instruction order.

## 5. Continue directly into guided work

The status response is a launch point, not a dead-end report.

1. List incomplete H4 items as ordered choices, always showing both ID and title.
2. Accept a follow-on response by displayed list number, case-insensitive ID, full title, or an
   unambiguous distinctive title phrase.
3. If a title phrase is ambiguous, show only the matches as an ordered list and ask again.
4. Once selected, continue immediately with the **Guided-work contract** in
   `/otus-instructions`. Read that sibling skill if it is not already loaded. Do not make the
   student type another command.
5. Ask the relevant questions, help update the artifact, confirm presence, then list the remaining
   work items exactly as `/otus-instructions` would.

## Boundaries

1. Presence, not quality; guidance, not grading.
2. Never collapse H4 children into an H3-level pass.
3. Never expose internal data-source vocabulary to the student.
4. Do not diagnose identity, push, or capture here. If repository state suggests a connection
   problem, include `/otus-verify-connection` as one numbered next action.

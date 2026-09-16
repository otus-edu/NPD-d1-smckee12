---
name: otus-instructions
description: >-
  Navigate this deliverable's authoritative INSTRUCTIONS.md and actively guide the student through
  one actionable H4 work item at a time. Invoke when the student types /otus-instructions, asks
  what to do, asks for the brief or a named component, or wants help starting the work. Presents
  ordered H4 choices with IDs and titles; accepts a list number, ID, or title; then asks the
  relevant questions and helps update the artifact. INSTRUCTIONS.md is read-only because OTUS
  holds the authoritative copy.
---

# /otus-instructions — choose a work item and work through it

OTUS holds the authoritative copy of `INSTRUCTIONS.md`. Read it, but never edit it.

The useful unit of work is an H4 item such as `D1a-1 — JTBD Analysis`, not its H3 parent. Help the
student complete one H4 item; do not merely display its requirements and leave them to translate
those requirements into mechanics.

## 1. Load the brief and work-item data

Read `INSTRUCTIONS.md`. Read `.otus/manifest.json` when present, but treat it as internal data and
**never mention the manifest, detectors, schema, or parsing to the student**.

Build the ordered work-item list as follows:

1. Use `work_items` from `.otus/manifest.json` when present. Preserve array order.
2. Otherwise, derive one work item from every `#### D<N><letter>-<n> — Title` heading under
   `## Deliverable Instructions`, in document order.
3. For a derived item, use its Objective, Expected Outcome, Requirements, Tips, named files, and
   H3 parent as the guidance context.
4. Never substitute an H3 component for its H4 children. If a brief genuinely has no H4 items,
   use the shallowest actionable headings it does have.

Supported optional `work_items` fields are declarative, not deliverable-specific skill logic:

1. `id` and `title` — the student-facing identifier and title.
2. `path` and optional `sections` — where the work belongs.
3. `coach.mode` — a hint such as `questionnaire`, `guided_draft`, `artifact_edit`, `link`,
   `prototype`, or `review`.
4. `coach.questions` — ordered elicitation questions.
5. `complete_when` — presence-oriented evidence used by `/otus-status`; never a quality rubric.

If a field is absent, infer the mechanics from the H4 instructions and repository. Do not require
metadata to help the student.

## 2. Orient and show ordered choices

Start with the deliverable title, instruction version, and one sentence from the Overview. Then
show every actionable work item as a single ordered list. Every choice must include both its ID
and title:

```text
Onboarding Questionnaire · v6 (updated 2026-08-20)

1. D0a-1 — Who You Are → questionnaire.md
2. D0a-2 — Your Background → questionnaire.md
3. D0a-3 — This Course → questionnaire.md

Choose 1–3, an item ID, or an item title. For example: "2", "D0a-2", or "Your Background".
```

Use ordered lists for all choices, questions, requirements, progress, and next actions. Nested
material must also be ordered. Do not use bullets or lettered `a/b/c` menus.

Accept a selection by:

1. Its displayed list position.
2. Its ID, case-insensitively (`D0a-2`). Accept a dotted typo (`D0a.2`) and echo the dashed ID.
3. Its full title, case-insensitively.
4. An unambiguous distinctive title phrase.

If a title phrase matches more than one item, show only those matches as a new ordered list and ask
again. Never guess. The item title must remain visible whenever confirming a selection or naming a
next item.

The student may also request `overview`, `how you work`, or `all`. Render that requested text
verbatim, then return to the numbered H4 choices.

## 3. Guided-work contract

Once an item is selected, begin the work in the same turn. Do not default to dumping the complete
H4 prose or offering another menu.

1. Name the selected item as `ID — Title` and summarize its expected outcome in one sentence.
2. Open the destination artifact and inspect the relevant section, existing work, and shipped
   placeholder.
3. Use `coach.questions` when supplied. Otherwise derive the smallest set of concrete questions
   whose answers are sufficient for the H4 Requirements and Expected Outcome.
4. Ask questions one at a time by default. If several short factual fields naturally belong
   together, an ordered batch is acceptable; never present an unstructured wall of prompts.
5. Adapt questions to what is already written. Do not ask the student for information the artifact
   already contains.
6. Translate the student's answer into the required artifact shape, show or summarize the proposed
   change, and update the named file when authorized by their request.
7. Preserve the student's meaning and voice. Ask a focused follow-up when required information is
   missing; do not invent facts, research, evidence, decisions, or links.
8. Continue until the selected item's `complete_when` evidence—or, without metadata, all of its H4
   Requirements—is present. This is presence, not a judgment of quality.

Examples of generic mechanics:

1. `questionnaire` — ask the named questions, capture short answers, and replace the corresponding
   placeholders.
2. `guided_draft` — elicit the claim, supporting observations, boundaries, and required facts;
   shape them into the requested paragraph, table, or section.
3. `artifact_edit` — inspect the existing artifact, identify the required change, then edit it with
   the student.
4. `link` or `prototype` — help create or locate the artifact, then place its URL in the required
   destination; never fabricate a URL.
5. `review` — compare the artifact with presence-oriented requirements and help fill omissions;
   never grade quality.

## 4. Continue with ordered next actions

After completing or pausing an item, give an ordered, referenceable next step:

1. State what was added or what remains for `ID — Title`.
2. List the remaining H4 work items in instruction order, including both ID and title.
3. Accept the next choice by list position, ID, or title and repeat the same guided-work contract.
4. Include `/otus-status` as the final numbered option when a whole-deliverable check would help.

## 5. Instruction changes

The repo copy is a provisioning snapshot. If the OTUS Deliverables page differs, OTUS wins. Tell
the student to follow the OTUS wording and flag the difference to the instructor. Do not promise a
git resync and do not edit `INSTRUCTIONS.md`.

## Boundaries

1. Read and guide; never grade.
2. Never edit `INSTRUCTIONS.md`.
3. Keep setup, capture, and submission mechanics out of this flow; point to
   `/otus-verify-connection`, `/otus-submit`, or the OTUS Deliverables page.
4. Keep implementation terms internal. Speak only about the brief, work items, requirements,
   artifacts, and progress.

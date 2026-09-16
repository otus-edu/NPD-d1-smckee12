---
name: otus-submit
description: >-
  Submit this deliverable from the repository. Invoke when the student or team types /otus-submit,
  says they are done, wants to hand in the work, or asks about the submission tag. Checks every
  actionable H4 work item for presence, commits outstanding work under a real identity, pushes the
  commit, creates and pushes the correct submission tag, verifies that tag on the remote, and sends
  the student back to OTUS for the authoritative receipt. Team deliverables require a merged review
  before tagging. Never grades quality or treats a local-only tag as submitted.
---

# /otus-submit — check, push, tag, verify

Submission is a remote git tag. A local tag is not a submission: GitHub cannot see it, and OTUS's
GitHub webhook cannot record it.

Use ordered lists for all student-facing checks, missing-work reports, choices, and next actions.
Never use lettered menus.

## 1. Read submission context

Read `.otus/deliverable.json` for `deliverable_key` and `unit`. Read
`.otus/manifest.json` for the declared `submission_tag` when present; otherwise use
`<deliverable_key>-submitted`.

Treat these sources as internal. Do not mention manifests, detectors, or schemas to the student.

If `unit` is missing, assume `individual` unless the repository clearly belongs to a team.

## 2. Check H4 work-item completion

Run the same H4-level presence check defined by `/otus-status`. Read that sibling skill if needed.

1. Check every actionable H4 item independently.
2. Exclude the submission tag from the content-completion denominator and pre-submit gate.
3. If any required H4 item is incomplete, stop before committing or tagging.
4. Report each missing item as an ordered choice with both ID and title.
5. Accept a follow-on choice by list number, ID, or title and continue directly through
   `/otus-instructions`'s Guided-work contract.
6. Proceed past incomplete content only after an explicit “submit anyway”; state that the snapshot
   will be visibly incomplete. Presence, never quality.

## 3. Confirm commit identity, then commit

Before creating any commit:

```sh
git config user.name
git config user.email
```

1. Stop if either value is unset, uses the OTUS bot identity, or is obviously shared/team-generic.
2. Help set the student's own identity, then re-check it.
3. Inspect `git status --porcelain` and the diff.
4. Exclude secrets, capture tokens/device files, `.env`, dependencies, build output, and large
   binaries.
5. Commit related outstanding work with an accurate message. Split clearly unrelated changes.
6. If the tree is clean, continue without creating an empty commit.

Identity is required for authorship; it is also checked by `/otus-verify-connection`.

## 4. Put the commit on GitHub

For an individual deliverable:

1. Push the current branch with `git push origin HEAD`.
2. Stop and troubleshoot if the push fails. Never create a submission tag for a commit that is not
   on the remote.

For a team deliverable:

1. Push the working branch with `git push origin HEAD`.
2. Open a pull request into `main`.
3. Stop while the pull request is open. A teammate must review and merge it.
4. After merge, update local `main` with `git checkout main` and `git pull --ff-only origin main`.
5. Tag only the reviewed, merged `main` commit.

Never tag an unmerged team branch.

## 5. Choose, create, and push an immutable submission tag

Fetch remote tag names before choosing:

```sh
git ls-remote --tags origin
```

Use the declared base tag for the first submission. If it already exists remotely:

1. If it resolves to the current commit and no new work exists, report that this snapshot is already
   on GitHub; do not recreate or move the tag.
2. If this is a later submission, choose the next unused sequential attempt tag:
   `<base>-r2`, `<base>-r3`, and so on.
3. Never force-move or delete an existing remote submission tag.

For the selected tag:

```sh
git tag <selected-tag> HEAD
git push origin refs/tags/<selected-tag>
```

If a matching local-only tag already exists at HEAD, push it rather than recreating it. If a
matching local tag points elsewhere, stop and explain the conflict; do not move it silently.

## 6. Verify GitHub, then hand confirmation to OTUS

Do not infer remote success from the local tag list or from a zero-exit tag creation. Verify the
exact remote ref:

```sh
git ls-remote --exit-code --tags origin refs/tags/<selected-tag>
```

Confirm the returned SHA matches the tagged commit. Then give exactly this shape of next steps,
adapted to the deliverable and tag:

1. “GitHub has `<selected-tag>` at `<short-sha>`.”
2. “Return to this deliverable in OTUS and confirm it shows Submitted at that commit.”
3. “Once OTUS confirms it, you can close this session.”

OTUS is authoritative for the submission receipt. A verified GitHub tag proves the webhook input
exists; it does not prove OTUS processed it. Never say “OTUS recorded it” until the student confirms
that state on OTUS.

## Boundaries

1. Check and submit; never grade.
2. Never treat a local-only tag as submitted.
3. Never tag incomplete content without a conscious override.
4. Never force-move an existing remote submission tag.
5. Never tag an unreviewed team branch.
6. Never expose or commit secrets or capture credentials.

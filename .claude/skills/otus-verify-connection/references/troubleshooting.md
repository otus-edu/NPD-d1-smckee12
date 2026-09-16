# Connection troubleshooting

Read only the section matching the failed check. Keep student-facing steps ordered.

## Push access

Work through these causes in order:

1. Confirm `origin` points to the OTUS-provisioned repository with `git remote -v`.
2. Confirm the GitHub collaborator invitation was accepted. The student can check GitHub
   notifications or the invitation email.
3. Confirm git is authenticated as the GitHub account verified in OTUS. Agent, OTUS, and commit
   emails do not need to match, but repository access belongs to the verified GitHub account.
4. Refresh stale credentials using the agent's normal GitHub authentication flow.
5. Re-run `git push --dry-run origin HEAD` once.

Do not change the remote to a guessed URL. If the expected repository is unclear, have the student
open it from the OTUS Deliverables page.

## Hook wiring

1. Confirm the repository was provisioned by OTUS and `.otus/deliverable.json` contains a real
   iteration ID.
2. Claude Code:
   1. Confirm `.claude/settings.json` contains a Stop hook for `sh .otus/capture.sh`.
   2. Confirm `.otus/capture.sh` exists.
   3. If repository hook trust was declined, reopen the repository and approve its hooks.
3. Codex:
   1. Confirm `.codex/hooks.json` contains a Stop hook for
      `node .otus/capture-codex.mjs`.
   2. Confirm `.otus/capture-codex.mjs` exists.
   3. If either provisioned file is absent, direct the student to repair/reopen the repo from OTUS;
      do not improvise a replacement credential adapter.

## Approval page

1. Always display the URL, repository, and matching code even when the shell reports that it opened
   a browser.
2. If no browser opens, use the agent's supported link-opening capability.
3. If the link expires, run `start` once more and show the replacement values.
4. If OTUS reports too many pending approvals, wait for the server-specified interval; do not loop.
5. If the page names a different repository or code, do not approve it. Start a fresh flow from the
   intended repository.

## Capture receipt

1. A token proves local enablement, not server delivery.
2. Under Codex, run the explicit current-task receipt check once. If network access is denied,
   request permission narrowly for that command and retry once.
3. Under Claude Code, the Stop hook posts at the end of the turn. The student confirms the result on
   the OTUS Deliverables page.
4. A missing or stale OTUS result after a verified hook run should be reported with only safe state:
   repository, timestamp, agent, and the adapter's non-secret reason. Never include a token,
   device-secret, or transcript body.

## Cloud or ephemeral environments

A repo-local token may disappear with the container. For durable cloud use:

1. Open the capture setup on the OTUS Deliverables page.
2. Add `OTUS_CAPTURE_TOKEN` to the selected agent environment.
3. Allowlist the OTUS capture domain under the environment's network settings.
4. Open future sessions with that environment, not an unconfigured default environment.

Never ask the student to paste a token into chat or print it in a terminal transcript.

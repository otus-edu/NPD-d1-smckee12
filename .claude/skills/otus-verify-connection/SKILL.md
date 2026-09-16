---
name: otus-verify-connection
description: >-
  Verify this repo's OTUS connection through a fixed consent-first flow: commit identity, dry-run
  push access, agent-specific capture-hook wiring, and capture enablement. Invoke when the student
  types /otus-verify-connection, asks whether setup works, cannot push, has incorrect authorship,
  or OTUS shows no recent capture. Always displays the capture consent first and proceeds after
  an affirmative reply such as “I agree,” “okay,” or “yes.” Uses a consistent browser approval flow and
  ends by sending the student to OTUS for authoritative confirmation.
---

# /otus-verify-connection — consent, check, confirm in OTUS

## 1. Consent is always first

On every invocation, before reading files, inspecting environment variables, running git, checking
prior results, or taking any other action, print this consent disclosure:

> Transcript Capture lets OTUS see the Claude Code / Codex agent sessions you run in this repository, so your agent interaction can be assessed by your instructor. This is for feedback only: with Transcript Capture on, your instructor is able to give you feedback not only on what you submit in your deliverables, but also how well you are using AI. Transcript capture does not impact your deliverable completion or your grade.

Then print:

> Please confirm you wish to turn Transcript Capture on with “I agree.” If not, simply shut this session down.

Stop and wait. Do not run any check in the same turn as the consent disclosure.

First recognize an explicit refusal such as `no`, `no thanks`, `decline`, or `do not enable`.
It stops this skill. Capture remains optional and never gates completion or a grade. Record that
choice in `.otus/capture-declined` so the session-start prompt respects it. A later affirmative
response while invoking this skill reverses that choice; remove the decline marker and continue.

Otherwise, proceed when the student's next response, after trimming surrounding whitespace and
comparing case-insensitively, is `I agree`, `okay`, `yes`, or `agree`. For any other response, say
only: “Please reply with the exact phrase ‘I agree’.” Do not repeat the disclosure or start a new
approval flow.

Do not add agent/model-specific wording to the consent disclosure.

## 2. Run background checks before approval

After valid consent, run the identity, push-access, and hook-wiring checks. Do not present the
full user-visible checklist yet. These checks provide context for the approval flow and avoid
making the student run this skill again after approval. If a check needs student action, ask only
for that focused fix, then continue the same flow; keep the collected results for the final report.

## 3. Check capture and launch approval

Use the following checks in the background:

### Identity

```sh
git config user.name
git config user.email
```

Pass only when both values are present and identify a real individual—not `OTUS Bot`,
`otus-bot@users.noreply.github.com`, or an obviously shared/team identity.

Identity is part of connection readiness because commits carry authorship. Under Claude Code it also
enables auto-save; under Codex there is no auto-save, so the student must commit as they work.

If identity fails, ask for the student's name and commit email, set them locally in this repository,
and re-run this check. Do not rewrite already-pushed shared history.

### Push access

```sh
git push --dry-run origin HEAD
```

Pass only when the dry run succeeds. This proves the current credentials can write to the
OTUS-provisioned remote. If it fails, read
`references/troubleshooting.md` and follow **Push access**.

### Hook wired

Determine which agent is running and check only its expected hook:

1. Claude Code — `.claude/settings.json` has a `Stop` hook that runs `sh .otus/capture.sh`,
   and `.otus/capture.sh` exists.
2. Codex — `.codex/hooks.json` has a `Stop` hook that runs
   `node .otus/capture-codex.mjs`, and `.otus/capture-codex.mjs` exists.

OTUS writes the Codex hook during provisioning, so its absence is a real setup failure even though
it is not in the template. A hook file is wiring evidence, not proof that OTUS received a capture.

If this check fails, read `references/troubleshooting.md` and follow **Hook wiring**.

### Capture enabled

Check presence without reading or printing credentials:

```sh
[ -n "${OTUS_CAPTURE_TOKEN:-}" ] && echo "environment token: present" || echo "environment token: absent"
[ -s .otus/capture-token ] && echo "local token: present" || echo "local token: absent"
```

Also confirm `.otus/deliverable.json` has a real `iteration_id`, not `<iteration_id>`.

1. A token is present — do not mint another. Under Codex, run the immediate receipt check below.
2. No token is present — run the approval flow below. The affirmative response already supplied is
   authorization to start it; do not ask a second generic consent question.
3. A placeholder iteration ID — fail and tell the student provisioning must be repaired in OTUS.

Never read back, print, log, or commit a capture token or device secret.

Use the helper beside this skill:

```sh
sh .claude/skills/otus-verify-connection/capture-approve.sh start
```

Under Codex use the byte-identical `.codex/skills/.../capture-approve.sh` path.

The helper prints `approve_url`, `code`, `repo`, and `browser_opened`. Always show the same
ordered instructions:

1. Open **<approve_url>**. If the helper did not open it, use the agent's supported browser-opening
   capability immediately.
2. Confirm the page shows repository **<repo>**.
3. Confirm the page code is **<code>**.
4. Select **Turn on capture**.
5. Keep this session open while the skill finishes checking approval.

Start polling immediately in the same turn:

```sh
sh .claude/skills/otus-verify-connection/capture-approve.sh poll
```

Use the Codex path under Codex. The helper waits for up to about four minutes.

1. `approved:` — the token is stored without entering output. Continue to receipt verification.
2. `pending:` — tell the student the page is still waiting and pause for their reply; do not ask
   them to invoke this skill again.
3. Exit 2 — the link expired or was spent; start once more and display the new URL/code/repo.
4. Exit 1 — show the helper's safe error and use the matching troubleshooting section.

Do not repeatedly poll after a pending result without new student input.

## 4. Show the checklist and verify a receipt

For Codex, approval polling may already print `capture_posted: yes|no`. If it does not, or the
token existed before this run, execute:

```sh
if [ -n "${CODEX_THREAD_ID:-}" ] && rg -q 'EXPLICIT_CURRENT_CAPTURE' .otus/capture-codex.mjs 2>/dev/null; then
  node .otus/capture-codex.mjs --current
fi
```

1. `capture_posted: yes` — OTUS accepted this task or identified an exact duplicate.
2. `capture_posted: no` — capture is locally enabled but not receipt-verified. Report the safe
   reason; retry once only when a narrow network permission was the cause.
3. No explicit-current support — report that the provisioned adapter needs an update; do not turn
   local wiring into a green server check.

Claude Code posts through its Stop hook at the end of the turn. Report capture as locally enabled
when the token and hook are present, then make the OTUS page the final confirmation. Do not claim a
server receipt merely from local files.

## 5. Report and send the student back to OTUS

Use this ordered shape, with actual evidence:

```text
/otus-verify-connection

1. ✓ PASS identity — Jane Doe <jane@school.edu>
2. ✓ PASS push access — dry-run push to origin succeeded
3. ✓ PASS hook wired — Codex Stop hook points to the OTUS capture adapter
4. ✓ PASS capture enabled — OTUS accepted this task's capture

Next:
1. Return to this deliverable in OTUS.
2. Confirm OTUS shows capture as active or shows a recent capture for this repo.
3. Once OTUS confirms it, close this session.
```

Show this checklist only after capture approval completes or when capture is already enabled. If a
pre-approval check needs attention, give its focused fix without rendering the checklist, then
resume the same approval flow. Never say “all clear” based only on local state; OTUS is
authoritative for the capture receipt.

## Boundaries

1. Always request consent first and wait for an affirmative response.
2. Never expose or commit capture credentials.
3. Capture is optional feedback and never gates deliverable completion or grading.
4. Keep output ordered and consistent across Claude Code, Codex, and model choices.
5. Stop after one bounded retry for network, approval, or receipt failures; never make the student
   restart the skill merely because approval was pending or initially missing.

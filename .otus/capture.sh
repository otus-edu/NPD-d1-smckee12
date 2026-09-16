#!/bin/sh
# OTUS deliverable capture — invoked by the Stop hook (.claude/settings.json).
# Reads the session transcript and POSTs the v1 capture payload contract
# (contract_version:1) to OTUS for observation. Must NEVER block the student:
# exit 0 on any error. Capture is opt-in — no token, no capture.
#
# Byte-identical across every deliverable template (d0-d5): deliverable_key comes from
# .otus/deliverable.json, not from anything hardcoded here.
set -eu

# 1. Token: env first, then a git-ignored file at the repo root. Never read
# it from anything tracked in git, and never write it anywhere.
token="${OTUS_CAPTURE_TOKEN:-}"
if [ -z "$token" ] && [ -f ".otus/capture-token" ]; then
  token="$(cat .otus/capture-token 2>/dev/null || true)"
fi
[ -n "$token" ] || exit 0

# The Stop hook passes hook JSON on stdin (includes "session_id" and
# "transcript_path").
hook_payload="$(cat 2>/dev/null || true)"
transcript_path="$(printf '%s' "$hook_payload" | sed -n 's/.*"transcript_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
session_id="$(printf '%s' "$hook_payload" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
[ -n "$transcript_path" ] && [ -f "$transcript_path" ] || exit 0
[ -n "$session_id" ] || exit 0

# 2. Config (non-secret): iteration_id + deliverable_key (+ optional
# functions_url override) come from the committed .otus/deliverable.json.
# OTUS injects the real values at provisioning.
deliverable_json=".otus/deliverable.json"
[ -f "$deliverable_json" ] || exit 0
deliverable_key="$(sed -n 's/.*"deliverable_key"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$deliverable_json")"
iteration_id="$(sed -n 's/.*"iteration_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$deliverable_json")"
functions_url="$(sed -n 's/.*"functions_url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$deliverable_json")"
[ -n "$functions_url" ] || functions_url="https://dbcweovuwyaypiocvmuy.supabase.co/functions/v1"
[ -n "$deliverable_key" ] && [ -n "$iteration_id" ] || exit 0

# repo.owner/repo.name from the git remote — never hardcoded, since OTUS
# provisions a fresh repo per student.
remote_url="$(git remote get-url origin 2>/dev/null || true)"
[ -n "$remote_url" ] || exit 0
repo_path="$(printf '%s' "$remote_url" | sed -e 's#^git@[^:]*:##' -e 's#^[a-zA-Z][a-zA-Z0-9+.-]*://[^/]*/##' -e 's#\.git$##')"
case "$repo_path" in
  */*) ;;
  *) exit 0 ;;
esac
repo_owner="${repo_path%%/*}"
repo_name="${repo_path#*/}"
[ -n "$repo_owner" ] && [ -n "$repo_name" ] || exit 0

posted_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

transcript_file="$(mktemp 2>/dev/null || true)"
body_file="$(mktemp 2>/dev/null || true)"
[ -n "$transcript_file" ] && [ -n "$body_file" ] || exit 0
trap 'rm -f "$transcript_file" "$body_file"' EXIT

# transcript: normalized to the shared capture contract by .otus/capture-filter.mjs,
# which keeps the conversation (prompts, replies, reasoning, tool calls/results)
# and drops the ~96% of a raw session file that is attachments, duplicated tool
# payloads and per-turn bookkeeping. Node ships with Claude Code, so it is
# present in practice; if it is missing or the filter fails for any reason we
# fall back to the raw JSONL rather than lose the capture.
if command -v node >/dev/null 2>&1 && [ -f ".otus/capture-filter.mjs" ]; then
  node ".otus/capture-filter.mjs" "$transcript_path" > "$transcript_file" 2>/dev/null || : > "$transcript_file"
fi
if [ ! -s "$transcript_file" ]; then
  # Each line of the session file is already a JSON object.
  printf '[%s]' "$(tr '\n' ',' < "$transcript_path" | sed 's/,$//')" > "$transcript_file"
fi
[ -s "$transcript_file" ] || exit 0

# content_hash = sha256 of the transcript we actually send, so the hash attests
# the stored payload. The server dedups on session_id+content_hash, so a Stop
# hook firing on a turn that added only filtered-away noise now dedups instead
# of storing a second near-identical row.
if command -v sha256sum >/dev/null 2>&1; then
  content_hash="$(sha256sum "$transcript_file" | awk '{print $1}')"
elif command -v shasum >/dev/null 2>&1; then
  content_hash="$(shasum -a 256 "$transcript_file" | awk '{print $1}')"
elif command -v openssl >/dev/null 2>&1; then
  content_hash="$(openssl dgst -sha256 "$transcript_file" | awk '{print $NF}')"
else
  exit 0
fi
[ -n "$content_hash" ] || exit 0

# Streamed rather than interpolated: the transcript never has to fit in a shell
# variable.
{
  printf '{"contract_version":1,"capture_token":"%s","repo":{"owner":"%s","name":"%s"},"deliverable_key":"%s","iteration_id":"%s","session_id":"%s","content_hash":"%s","posted_at":"%s","transcript":' \
    "$token" "$repo_owner" "$repo_name" "$deliverable_key" "$iteration_id" "$session_id" "$content_hash" "$posted_at"
  cat "$transcript_file"
  printf '}'
} > "$body_file"

curl -fsS -X POST "${functions_url}/deliverable-capture" \
  -H "Content-Type: application/json" \
  --data-binary "@${body_file}" >/dev/null 2>&1 || true

exit 0

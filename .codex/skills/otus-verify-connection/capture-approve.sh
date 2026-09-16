#!/bin/sh
# OTUS capture — device-flow helper for /otus-verify-connection.
#
# Turns "mint a token in OTUS, copy it, paste it here" into "click a link".
# Driven by the SKILL, never by a hook: the Stop hook's stdout is not reliably
# shown in the Claude Code desktop app, and an approve URL nobody sees is a dead
# flow.
#
# Two modes, because the student has to be able to SEE the approve link while
# the flow is still open:
#
#   sh capture-approve.sh start   opens a pairing code, prints the link + code
#   sh capture-approve.sh poll    checks once (waiting up to ~45s), and on
#                                 approval writes .otus/capture-token
#
# SECRETS NEVER REACH STDOUT. Two different secrets are in play and neither is
# ever printed, because everything this script prints ends up in the agent's
# transcript — which is itself uploaded to OTUS:
#   * the device secret — held in .otus/capture-device (mode 600, git-ignored)
#     between the two modes, and deleted the moment the flow ends;
#   * the capture token — written straight to .otus/capture-token (mode 600,
#     git-ignored) out of the response body, never echoed, never in a variable
#     that gets printed.
#
# Exit codes (this is an interactive diagnostic, so failure IS reported — unlike
# .otus/capture.sh, which must exit 0 on every path so capture never blocks):
#   0  did what was asked (start opened a code; poll approved, or is pending)
#   1  could not run — missing config, no network, server error, malformed response
#   2  the code expired or was already used, or there is no flow open; start one
#
# Every OTUS response is read for its HTTP STATUS as well as its body — see
# http_post below for why that is load-bearing rather than tidiness.
set -eu

STATE_FILE=".otus/capture-device"
TOKEN_FILE=".otus/capture-token"
# Four minutes covers the real browser round-trip without keeping a stale code
# alive indefinitely. Tests may shorten both values; production callers should
# leave them unset.
POLL_SECONDS_MAX="${OTUS_CAPTURE_POLL_SECONDS_MAX:-240}"
POLL_SLEEP="${OTUS_CAPTURE_POLL_SLEEP:-3}"

die() {
  echo "$1" >&2
  exit "${2:-1}"
}

# Best-effort browser open. Local sessions only — a cloud container has no
# display for the student to see. Run the opener to completion rather than
# backgrounding it: Codex can tear down a sandboxed child as soon as this helper
# exits, which made a reported-success open produce no window. Output is still
# swallowed because it lands in the transcript. The return value is reported so
# the skill can fall back to Codex's own browser/open capability.
open_url() {
  [ "${OTUS_CAPTURE_SKIP_BROWSER_OPEN:-0}" = "1" ] && return 1
  if [ "$(uname -s 2>/dev/null || true)" = "Darwin" ] && command -v open >/dev/null 2>&1; then
    open "$1" >/dev/null 2>&1 && return 0
  fi
  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$1" >/dev/null 2>&1 && return 0
  fi
  if command -v open >/dev/null 2>&1; then
    open "$1" >/dev/null 2>&1 && return 0
  fi
  if command -v start >/dev/null 2>&1; then
    start "" "$1" >/dev/null 2>&1 && return 0
  fi
  return 1
}

# POST some JSON; set $http_status and $http_body.
#
# `curl -f` is deliberately NOT used here, and that is the whole point of this
# function. `-f` suppresses the response body on a 4xx — but this API puts the
# thing we most need to read INSIDE the body of a 404: /poll answers an expired,
# already-redeemed, or wrong-secret code with 404 {"state":"expired"}. With -f
# the script saw an empty string, could not tell that apart from a dropped
# packet, and told the student "not approved yet" forever. /start had the same
# fault: its 429 ("too many pending approvals — wait a few minutes") arrived as
# "check your connection".
#
# A transport failure (genuinely no network) yields status 000 with an empty
# body, which callers treat differently from any real HTTP status.
http_post() {
  raw="$(curl -sS -w '\n%{http_code}' -X POST "$1" \
    -H "Content-Type: application/json" \
    --data "$2" 2>/dev/null || true)"
  http_status="$(printf '%s' "$raw" | tail -n 1)"
  http_body="$(printf '%s' "$raw" | sed '$d')"
  case "$http_status" in
    [0-9][0-9][0-9]) ;;
    *) http_status="000"; http_body="" ;;
  esac
}

# The server's own error text when it sent one, else the fallback. Server
# messages are written for the student ("Too many pending approvals for this
# repo. Wait a few minutes."), so they beat anything generic we'd invent.
server_error() {
  message="$(printf '%s' "$http_body" | json_field error)"
  [ -n "$message" ] && printf '%s' "$message" || printf '%s' "$1"
}

json_field() {
  # $1 = field name, reads the JSON blob on stdin. Flat objects only — same
  # approach as .otus/capture.sh, and for the same reason (no jq dependency).
  sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p"
}

require_config() {
  [ -f ".otus/deliverable.json" ] || die "No .otus/deliverable.json — run this from the repo root."

  iteration_id="$(json_field iteration_id < .otus/deliverable.json)"
  functions_url="$(json_field functions_url < .otus/deliverable.json)"
  [ -n "$functions_url" ] || functions_url="https://dbcweovuwyaypiocvmuy.supabase.co/functions/v1"

  case "$iteration_id" in
    "" | "<iteration_id>")
      die "This repo's .otus/deliverable.json still has a placeholder iteration_id — provisioning didn't finish. Flag it on the OTUS surface; you can't fix this from here."
      ;;
  esac

  remote_url="$(git remote get-url origin 2>/dev/null || true)"
  [ -n "$remote_url" ] || die "No 'origin' remote — is this the OTUS-provisioned repo?"
  repo_path="$(printf '%s' "$remote_url" | sed -e 's#^git@[^:]*:##' -e 's#^[a-zA-Z][a-zA-Z0-9+.-]*://[^/]*/##' -e 's#\.git$##')"
  case "$repo_path" in
    */*) ;;
    *) die "Couldn't read owner/name from the origin remote." ;;
  esac
  repo_owner="${repo_path%%/*}"
  repo_name="${repo_path#*/}"
}

do_start() {
  require_config

  if [ -n "${OTUS_CAPTURE_TOKEN:-}" ]; then
    echo "already-configured: OTUS_CAPTURE_TOKEN is set in this environment; nothing to approve."
    exit 0
  fi
  if [ -s "$TOKEN_FILE" ]; then
    echo "already-configured: $TOKEN_FILE exists; nothing to approve."
    exit 0
  fi

  body="{\"iteration_id\":\"${iteration_id}\",\"repo_owner\":\"${repo_owner}\",\"repo_name\":\"${repo_name}\"}"
  http_post "${functions_url}/capture-device/start" "$body"

  case "$http_status" in
    200) ;;
    000) die "Couldn't reach OTUS to start approval. Check your connection and try again." ;;
    429) die "$(server_error "Too many approvals already open for this repo. Wait a few minutes and try again.")" ;;
    *) die "$(server_error "OTUS couldn't start an approval (HTTP ${http_status}). Try again in a moment.")" ;;
  esac

  response="$http_body"
  code="$(printf '%s' "$response" | json_field code)"
  approve_url="$(printf '%s' "$response" | json_field approve_url)"
  # NOT printed — written to the state file below and read back by `poll`.
  device_secret="$(printf '%s' "$response" | json_field device_secret)"

  if [ -z "$code" ] || [ -z "$approve_url" ] || [ -z "$device_secret" ]; then
    die "OTUS returned an unexpected response starting approval. Try again in a moment."
  fi

  mkdir -p .otus
  ( umask 077; printf '%s\n%s\n' "$code" "$device_secret" > "$STATE_FILE" )
  chmod 600 "$STATE_FILE" 2>/dev/null || true

  if open_url "$approve_url"; then
    browser_opened="yes"
  else
    browser_opened="no"
  fi

  echo "code: $code"
  echo "approve_url: $approve_url"
  echo "repo: ${repo_owner}/${repo_name}"
  echo "browser_opened: $browser_opened"
  exit 0
}

do_poll() {
  require_config
  [ -f "$STATE_FILE" ] || die "No approval in progress — run 'start' first." 2

  code="$(sed -n '1p' "$STATE_FILE")"
  device_secret="$(sed -n '2p' "$STATE_FILE")"
  [ -n "$code" ] && [ -n "$device_secret" ] || {
    rm -f "$STATE_FILE"
    die "The approval state file was unreadable — run 'start' again." 2
  }

  waited=0
  reached_otus=0
  while [ "$waited" -le "$POLL_SECONDS_MAX" ]; do
    body="{\"code\":\"${code}\",\"device_secret\":\"${device_secret}\"}"
    # `http_body` holds a live credential once approved — it is never echoed.
    http_post "${functions_url}/capture-device/poll" "$body"
    [ "$http_status" = "000" ] || reached_otus=1

    response="$http_body"
    state="$(printf '%s' "$response" | json_field state)"

    if [ "$state" = "approved" ] && [ "$http_status" = "200" ]; then
      mkdir -p .otus
      ( umask 077; printf '%s' "$response" | json_field capture_token > "$TOKEN_FILE" )
      chmod 600 "$TOKEN_FILE" 2>/dev/null || true
      rm -f "$STATE_FILE"
      if [ -s "$TOKEN_FILE" ]; then
        echo "approved: capture token stored in $TOKEN_FILE (git-ignored)."
        # Codex Desktop can finish a task without dispatching its repo-local
        # Stop hook. Newer provisioned repos expose a safe explicit mode that
        # posts this task now and prints only a non-secret server receipt. It
        # runs inside the already-approved poll command, so no extra learner
        # reply or agent turn is needed. Older adapters simply skip this block.
        if [ -n "${CODEX_THREAD_ID:-}" ] && [ -f .otus/capture-codex.mjs ] &&
          grep -q 'EXPLICIT_CURRENT_CAPTURE' .otus/capture-codex.mjs 2>/dev/null; then
          node .otus/capture-codex.mjs --current || true
        fi
        exit 0
      fi
      rm -f "$TOKEN_FILE"
      die "Approval succeeded but the token couldn't be stored. Check you can write to .otus/."
    fi

    # Terminal states arrive as 404 WITH a body (see http_post). Reachable only
    # because this stopped using `curl -f`.
    if [ "$state" = "expired" ] || [ "$state" = "redeemed" ]; then
      rm -f "$STATE_FILE"
      die "That approval link expired or was already used. Run 'start' again for a fresh one." 2
    fi

    # A real HTTP error that isn't a known state — stop rather than spin.
    case "$http_status" in
      000 | 200 | 404) ;;
      *) die "$(server_error "OTUS couldn't check the approval (HTTP ${http_status}). Run 'start' again for a fresh link.")" ;;
    esac

    # Status 000 = a network blip mid-flow; keep waiting rather than throwing
    # away a code the student may be about to approve.
    waited=$((waited + POLL_SLEEP))
    [ "$waited" -le "$POLL_SECONDS_MAX" ] && sleep "$POLL_SLEEP"
  done

  if [ "$reached_otus" = "0" ]; then
    die "Couldn't reach OTUS to check the approval. Check your connection, then run 'poll' again."
  fi

  echo "pending: not approved yet. Open the link, then run 'poll' again."
  exit 0
}

case "${1:-}" in
  start) do_start ;;
  poll) do_poll ;;
  *) die "usage: sh capture-approve.sh start|poll" ;;
esac

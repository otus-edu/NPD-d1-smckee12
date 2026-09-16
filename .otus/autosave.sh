#!/bin/sh
# OTUS token-free auto-save — a Stop-hook sibling of capture.sh (journey brief §13).
# Commits + pushes in-progress work every time Claude Code stops, so a student who
# runs low on model tokens never loses work or misses a deadline. It is a
# deterministic shell script → uses ZERO model tokens.
#
# This SAVES; it does NOT SUBMIT. Submission is the deliberate, token-bearing
# /otus-submit (which runs the completion check and creates the `<key>-submitted`
# tag). Must NEVER block the student: exit 0 on any error.
#
# Byte-identical across every deliverable template (d0-d5).
set -eu

# Must be inside a git repo with an origin remote.
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
git remote get-url origin >/dev/null 2>&1 || exit 0

# Nothing changed since the last save? Then there's nothing to do.
[ -n "$(git status --porcelain 2>/dev/null)" ] || exit 0

# Commit as the student's OWN identity — never as the OTUS bot. Bot-authored work
# does not count toward completion and pollutes attribution, so if the identity is
# unset or is the bot, skip (the student sets it via /otus-verify-connection).
name="$(git config user.name 2>/dev/null || true)"
email="$(git config user.email 2>/dev/null || true)"
[ -n "$name" ] && [ -n "$email" ] || exit 0
case "$email" in
  otus-bot@users.noreply.github.com) exit 0 ;;
esac

git add -A 2>/dev/null || exit 0
git commit -m "wip: auto-save (OTUS, token-free hook)" >/dev/null 2>&1 || exit 0

# Push the current branch, best-effort (a detached HEAD has nothing to push).
branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
[ -n "$branch" ] && [ "$branch" != "HEAD" ] || exit 0
git push origin "$branch" >/dev/null 2>&1 || true

exit 0

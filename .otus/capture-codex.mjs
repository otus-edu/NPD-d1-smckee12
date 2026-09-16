#!/usr/bin/env node
import { createHash, createHmac } from "node:crypto";
import { execFileSync } from "node:child_process";
import { readdir, readFile, stat, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";

const DEFAULT_FUNCTIONS_URL = "https://dbcweovuwyaypiocvmuy.supabase.co/functions/v1";
const EXPLICIT_CURRENT_CAPTURE = process.argv.includes("--current");
let statusRoot = process.cwd();

async function readStdinJson() {
  let input = "";
  for await (const chunk of process.stdin) input += chunk;
  if (!input.trim()) return {};
  try {
    return JSON.parse(input);
  } catch {
    return {};
  }
}

async function findCurrentTranscript() {
  const threadId = String(process.env.CODEX_THREAD_ID ?? "").trim();
  if (!/^[a-f0-9-]{20,}$/i.test(threadId)) {
    throw new Error("The current Codex task ID is unavailable.");
  }

  const sessionsRoot = path.join(os.homedir(), ".codex", "sessions");
  const matches = [];
  async function walk(directory) {
    let entries = [];
    try {
      entries = await readdir(directory, { withFileTypes: true });
    } catch {
      return;
    }
    for (const entry of entries) {
      const candidate = path.join(directory, entry.name);
      if (entry.isDirectory()) {
        await walk(candidate);
      } else if (entry.isFile() && entry.name.includes(threadId) && entry.name.endsWith(".jsonl")) {
        const metadata = await stat(candidate);
        matches.push({ path: candidate, modified: metadata.mtimeMs });
      }
    }
  }
  await walk(sessionsRoot);
  matches.sort((a, b) => b.modified - a.modified);
  if (!matches[0]) throw new Error("The current Codex transcript is unavailable.");
  return { sessionId: threadId, transcriptPath: matches[0].path };
}

async function hookInput() {
  if (!EXPLICIT_CURRENT_CAPTURE) return await readStdinJson();
  const current = await findCurrentTranscript();
  return {
    hook_event_name: "OTUSImmediateCapture",
    session_id: current.sessionId,
    transcript_path: current.transcriptPath,
  };
}

async function writeCaptureStatus(root, status) {
  try {
    await writeFile(
      path.join(root, ".otus", "capture-status.json"),
      JSON.stringify({ ...status, recorded_at: new Date().toISOString() }, null, 2) + "\n",
      { mode: 0o600 },
    );
  } catch {
    // Status is diagnostic only; it must never make capture block the learner.
  }
}

function gitRoot() {
  try {
    return execFileSync("git", ["rev-parse", "--show-toplevel"], {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();
  } catch {
    return process.cwd();
  }
}

async function readTextIfExists(filePath) {
  try {
    return await readFile(filePath, "utf8");
  } catch {
    return "";
  }
}

async function captureToken(root) {
  const fromEnv = String(process.env.OTUS_CAPTURE_TOKEN ?? "").trim();
  if (fromEnv) return fromEnv;
  return (await readTextIfExists(path.join(root, ".otus", "capture-token"))).trim();
}

async function deliverableConfig(root) {
  const raw = await readTextIfExists(path.join(root, ".otus", "deliverable.json"));
  try {
    return JSON.parse(raw);
  } catch {
    return {};
  }
}

function originRepo(root) {
  try {
    const remote = execFileSync("git", ["-C", root, "remote", "get-url", "origin"], {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();
    const match =
      remote.match(/github\.com[:/](?<owner>[^/]+)\/(?<repo>[^/\s]+?)(?:\.git)?$/) ??
      remote.match(/^git@github\.com:(?<owner>[^/]+)\/(?<repo>[^/\s]+?)(?:\.git)?$/);
    if (match?.groups) return { owner: match.groups.owner, name: match.groups.repo.replace(/\.git$/, "") };
  } catch {
    // fall through
  }
  return { owner: "unknown", name: path.basename(root) || "unknown" };
}

// Truncation caps. Prose is what coaching reads, so it gets room; tool traffic
// only needs to show WHAT ran and whether it worked, not its full payload.
const TEXT_CAP = 10000;
const REASONING_CAP = 2000;
const TOOL_CAP = 500;
const TOTAL_CAP = 1000000;

// A user turn that is nothing but injected context is machinery, not something
// the student typed. Matched only when the text STARTS with the tag, so a real
// prompt that happens to quote one is kept.
const INJECTED_PREFIXES = [
  "<app-context>",
  "<skill>",
  "<environment_context>",
  "<recommended_plugins>",
  "<multi_agent_mode>",
  "<user_instructions>",
];

function isInjectedContext(text) {
  const trimmed = text.trimStart();
  return INJECTED_PREFIXES.some((tag) => trimmed.startsWith(tag));
}

function parseTranscript(raw) {
  const trimmed = raw.trim();
  if (!trimmed) return [];
  const events = [];
  for (const line of trimmed.split(/\r?\n/)) {
    if (!line.trim()) continue;
    try {
      events.push(JSON.parse(line));
    } catch {
      // A torn final line mid-write is normal; skip it.
    }
  }
  return events;
}

function textFrom(value) {
  if (typeof value === "string") return value;
  if (Array.isArray(value)) return value.map(textFrom).filter(Boolean).join("\n");
  if (value && typeof value === "object") {
    if (typeof value.text === "string") return value.text;
    if (typeof value.content === "string") return value.content;
    if (value.content) return textFrom(value.content);
  }
  return "";
}

/** Codex event stream -> normalized transcript contract v1. See the note above
 *  CODEX_CAPTURE_SCRIPT for the shape and why the raw stream is not shipped. */
function filterTranscript(entries) {
  const events = [];
  let spent = 0;
  let capped = false;

  const push = (role, text, timestamp, cap, toolName) => {
    if (capped) return;
    const body = String(text == null ? "" : text).trim();
    if (!body) return;
    if (spent >= TOTAL_CAP) {
      capped = true;
      events.push({
        source_tool: "codex",
        index: events.length,
        role: "system",
        text: "[OTUS capture: transcript truncated at the size cap; earlier turns are complete.]",
        timestamp: null,
      });
      return;
    }
    const clipped = body.length > cap;
    const event = {
      source_tool: "codex",
      index: events.length,
      role,
      text: clipped ? body.slice(0, cap) : body,
      timestamp: timestamp == null ? null : timestamp,
    };
    if (toolName) event.tool_name = toolName;
    if (clipped) event.truncated = true;
    spent += event.text.length;
    events.push(event);
  };

  for (const entry of entries) {
    // Only response_item carries conversation. session_meta / turn_context /
    // world_state are bookkeeping, and event_msg (item_completed, token_count,
    // thread_settings_applied, ...) re-states response_items already captured.
    if (!entry || entry.type !== "response_item") continue;
    const payload = entry.payload || {};
    const timestamp = entry.timestamp == null ? null : entry.timestamp;

    if (payload.type === "message") {
      // developer / system roles are injected instructions, not the student.
      if (payload.role !== "user" && payload.role !== "assistant") continue;
      const text = textFrom(payload.content);
      if (payload.role === "user" && isInjectedContext(text)) continue;
      push(payload.role, text, timestamp, TEXT_CAP);
    } else if (payload.type === "reasoning") {
      // summary only — encrypted_content is an opaque blob, never readable.
      push("reasoning", textFrom(payload.summary), timestamp, REASONING_CAP);
    } else if (payload.type === "custom_tool_call" || payload.type === "function_call") {
      const input = textFrom(payload.input) || payload.arguments;
      push("tool_call", input, timestamp, TOOL_CAP, payload.name);
    } else if (
      payload.type === "custom_tool_call_output" ||
      payload.type === "function_call_output"
    ) {
      push("tool_result", textFrom(payload.output), timestamp, TOOL_CAP);
    }
  }

  return events;
}

async function postCapture(url, body) {
  const headers = { "Content-Type": "application/json" };
  const secret = String(process.env.OTUS_CAPTURE_SECRET ?? "").trim();
  if (secret) {
    headers["X-Capture-Signature"] = "sha256=" + createHmac("sha256", secret).update(body).digest("hex");
  }
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 8000);
  try {
    const response = await fetch(url, { method: "POST", headers, body, signal: controller.signal });
    if (!response.ok) throw new Error("OTUS capture returned HTTP " + response.status + ".");
    try {
      const result = await response.json();
      return result?.status === "duplicate" ? "duplicate" : "accepted";
    } catch {
      return "accepted";
    }
  } finally {
    clearTimeout(timeout);
  }
}

async function main() {
  const hook = await hookInput();
  const root = gitRoot();
  statusRoot = root;
  const token = await captureToken(root);
  if (!token) {
    if (EXPLICIT_CURRENT_CAPTURE) throw new Error("Capture is not approved in this repository.");
    return;
  }

  const transcriptPath = typeof hook.transcript_path === "string" ? hook.transcript_path : "";
  const rawTranscript = transcriptPath ? await readTextIfExists(transcriptPath) : "";
  const transcript = filterTranscript(parseTranscript(rawTranscript));
  if (transcript.length === 0 && hook.last_assistant_message) {
    transcript.push({
      source_tool: "codex",
      index: 0,
      role: "assistant",
      text: String(hook.last_assistant_message),
      timestamp: null,
      note: "Fallback from Codex Stop hook last_assistant_message; transcript_path was unavailable or empty.",
    });
  }
  if (transcript.length === 0) {
    if (EXPLICIT_CURRENT_CAPTURE) throw new Error("The current Codex transcript is empty.");
    return;
  }

  const config = await deliverableConfig(root);
  const functionsUrl = String(config.functions_url ?? DEFAULT_FUNCTIONS_URL).replace(/\/+$/, "");
  const body = JSON.stringify({
    contract_version: 1,
    capture_token: token,
    repo: originRepo(root),
    deliverable_key: String(config.deliverable_key ?? ""),
    iteration_id: String(config.iteration_id ?? ""),
    session_id: String(hook.session_id ?? "codex-" + Date.now()),
    content_hash: createHash("sha256").update(JSON.stringify(transcript)).digest("hex"),
    posted_at: new Date().toISOString(),
    transcript,
  });

  const serverStatus = await postCapture(functionsUrl + "/deliverable-capture", body);
  await writeCaptureStatus(root, {
    status: "sent",
    server_status: serverStatus,
    session_id: String(hook.session_id ?? ""),
    hook_event_name: String(hook.hook_event_name ?? "Stop"),
  });
  if (EXPLICIT_CURRENT_CAPTURE) {
    console.log("capture_posted: yes");
    console.log("server_status: " + serverStatus);
  }
}

main().catch(async (error) => {
  const message = error instanceof Error ? error.message : "Capture post failed.";
  await writeCaptureStatus(statusRoot, { status: "error", message });
  if (EXPLICIT_CURRENT_CAPTURE) {
    console.error("capture_posted: no");
    console.error("reason: " + message);
    process.exitCode = 1;
  }
  // Hook mode remains fail-open: observation never blocks the learner's turn.
});

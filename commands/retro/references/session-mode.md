<!-- Derived from the `retroscope` plugin (0.3.1) in Tribe Coding claude-plugins, MIT License,
     Copyright (c) 2025 Tribe Coding. https://github.com/artem-from-ua/claude-plugins/tree/bcc769c14690b8d9da0230f8b3b34d551bb016e9/plugins/retroscope -->

# Session Mode — Implementation Reference

## Step 3a: Determine session data source

Read `sessionSource` from config (default: `logs`).

| Value | Behavior |
|-------|----------|
| `logs` (default) | Read JSONL session file — complete and reliable even if context was compressed or cleared |
| `context` | Use current conversation context — faster, no file I/O, but may miss earlier turns if context was compressed (`/compact`) or cleared (`/clear`) |

## Step 3b: Source: `logs`

Find the JSONL file for the current session:

1. Get current session ID — read `$CLAUDE_SESSION_ID` env var, or fall back to finding the most recently modified JSONL file under the encoded current project path:
   ```bash
   ls -t ~/.claude/projects/<encoded-project-dir>/*.jsonl | head -1
   ```
   **Never use the Read tool on `.jsonl` files — they can exceed 256 KB. Always use Bash commands.**

2. Resolve script path — `SCRIPT_DIR` = `${CLAUDE_PLUGIN_ROOT}/scripts`.

3. Run stats first:
   ```bash
   PYTHONPATH="" python3 {SCRIPT_DIR}/find-sessions.py --stats "{session_file}"
   ```

4. Extract conversation text:
   ```bash
   PYTHONPATH="" python3 {SCRIPT_DIR}/find-sessions.py --extract "{session_file}"
   ```
   (No `--date` filter — include all messages regardless of when session started.)

5. Read `${CLAUDE_PLUGIN_ROOT}/commands/retro/references/report-template.md`

6. Generate the report from the extracted text. Use `inherit` model (generate directly, no subagent — session reports don't benefit from a haiku subagent since Claude already has context).

7. Display in terminal. **Do NOT save to disk** — session reports are display-only.

## Step 3c: Source: `context`

> ⚠️ **Note:** Context may be incomplete if the conversation was compacted or cleared. Use `logs` for reliable coverage of the full session.

1. Read `${CLAUDE_PLUGIN_ROOT}/commands/retro/references/report-template.md`
2. Fill in the template from the current conversation history in context:
   - Review all visible conversation turns
   - Project = current working directory name
   - Date = today's date
   - Session count = 1 (current session)
3. Display in terminal. **Do NOT save to disk.**

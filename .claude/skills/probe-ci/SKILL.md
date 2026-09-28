---
name: probe-ci
description: Throwaway CI probe for the release-docs plan (V1). Not for real use.
disable-model-invocation: true
---

# Probe CI — Report What This Runner Can Do

1. Write the file `probe-out.txt` in the repository root with these two lines, filled in honestly:
   - `skills-visible: <comma-separated names of every skill you can invoke>`
   - `walkthrough-document: <yes if walkthrough:document is among them, else no>`
2. Dispatch the `probe-echo` agent with the prompt `ping`. Append `agent-reply: <its reply>` to `probe-out.txt`, or `agent-reply: FAILED <reason>` if the dispatch fails. Also append `agent-tool: <the exact name of the tool you used to dispatch it>`.
3. Protected-path writes. Try each of these once, and append one line per attempt to `probe-out.txt` with the exact outcome (quote any error or denial text verbatim):
   - With the Write tool, create `.claude/probe-write.txt` containing `ok`. Append `claude-dir-write: ok` or `claude-dir-write: DENIED <text>`.
   - With the Bash tool, run `echo ok > .claude/probe-redirect.txt`. Append `claude-dir-redirect: ok` or `claude-dir-redirect: DENIED <text>`.
   - With the Write tool, create `.github/probe-write.txt` containing `ok`. Append `github-dir-write: ok` or `github-dir-write: DENIED <text>`.
4. Reply `done`.

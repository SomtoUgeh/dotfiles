---
name: remote-session
description: Show the remote terminal session info (URL, credentials) for the current session
user_invocable: true
---

Read the file `/tmp/remote-session.txt` and print only the first 3 lines (URL, User, Pass) to the user. If the file doesn't exist, tell the user no remote session is active and they should start one with `remote-session` in their terminal.

# Privacy Policy

Academic Writing Toolkit supports research and thesis-writing workflows as a
local review workbench, a local Codex plugin, and a tool-only ChatGPT App.

## Local review workbench

The workbench runs an unauthenticated HTTP server restricted to the local
computer's loopback interface. It does not operate a hosted manuscript service,
create accounts, or intentionally collect analytics.

When the user starts an Agent analysis, the workbench sends the selected
manuscript content, selected evidence content, their filenames, the selected
task and manuscript purpose, and the author's stated goal to the configured
Codex provider. Oversized inputs may be reduced to deterministic excerpts and
summaries before that request. Files that were merely listed as local
candidates are not sent unless the user selects them. Users should review their
Codex provider's current data terms before using confidential or embargoed
material.

Recoverable sessions are stored in the user-configured filesystem location,
locally by default under `~/.local/share/academic-writing-toolkit/sessions`. A
session contains a copy of the selected source and evidence bytes, the Agent
analysis, review decisions, and integrity hashes. Session directories and files
are created with owner-only permissions. AWT does not independently encrypt
those files.
Deleting a session from the workbench performs ordinary file deletion; it does
not securely erase storage blocks, remove operating-system backups, or delete
separately downloaded review files and modified copies. The workbench never
overwrites the selected source file.

The plugin does not operate a hosted service, create user accounts, or intentionally collect analytics. Skills run in the user's local Codex workspace and read or write only the project files the user asks Codex to work with, such as chapters, literature notes, references, and export output.

The ChatGPT App version processes only text the user provides to ChatGPT for
the current tool call. The AWT App itself writes temporary files during
processing and deletes the files it controls after the request; it does not
create user accounts, intentionally collect analytics, or operate a persistent
user-content database. ChatGPT/OpenAI and the hosting infrastructure process
data under their own policies and user-account settings.

Some skills can use network access only when the user explicitly requests online verification, such as `/verify` fact-checking or `/verify-refs --online` metadata checks. In those cases, Codex may contact third-party sources such as CrossRef, Semantic Scholar, arXiv, or web pages relevant to the user's request. The plugin does not receive or store those requests separately.

The ChatGPT App submission build does not perform online metadata verification in its tools.

Users should not put confidential research material into public repositories or share exported outputs unless they intend to disclose that material.

For questions, use the repository issue tracker: https://github.com/yha9806/academic-writing-toolkit/issues

# Academic Writing Toolkit Plugin

This plugin packages the Academic Writing Toolkit skills for structured research and
thesis writing workflows. One `skills/` tree serves two hosts:
`.claude-plugin/plugin.json` for Claude Code and `.codex-plugin/plugin.json` for Codex.

This is the skills companion, not the local Workbench runtime. Installing it makes the 20
bundled workflows available to a compatible agent host; it does not install or start the
`awt` local web workbench. The Workbench is distributed separately as a wheel on the
[GitHub Releases page](https://github.com/yha9806/academic-writing-toolkit/releases).

The plugin does not require Gemini, gemini-agent, subagents, or external model review.
External review tools may be used as optional advisory inputs, but local files and bundled
checks remain the evidence boundary.

An enhanced advisory mode can use API-key-backed external review when the user explicitly opts in. API keys should stay in environment variables, and any external output remains advisory rather than evidence.

## Install

Claude Code:

```
/plugin marketplace add cosmosapjw-quantum/academic-writing-toolkit
/plugin install academic-writing-toolkit@academic-writing-toolkit
```

Codex:

```bash
codex plugin marketplace add yha9806/academic-writing-toolkit \
  --sparse .agents/plugins --sparse plugins/academic-writing-toolkit
codex plugin add academic-writing-toolkit@academic-writing-toolkit
```

## Included Skills

In Claude Code these load namespaced as `/academic-writing-toolkit:<skill>`.

- `read`: read academic PDFs page by page with structured output
- `note`: record source notes in the toolkit notes format
- `verify`: fact-check historical or empirical claims during reading
- `map`: map literature coverage against thesis chapters
- `evidence-review`: build evidence-controlled literature gap maps, claim registers, citation plans, and overclaim audits
- `argument-governance`: build and audit intent, gap-contribution chains, claim hierarchies, evidence balance, and reviewer risks
- `integrate`: integrate completed reading notes into chapter drafts
- `thesis-control`: keep AI-assisted thesis edits bounded with spine cards, edit contracts, drift audits, human gates, and draft packet scaffolding
- `manuscript-reframe`: turn report-like drafts into paper-form scientific arguments with clear gap, contribution, result narrative, figure/table roles, and submission blockers
- `revision-escalation`: stop repeated failed revisions and diagnose specification, structure, evidence, or version-contamination problems
- `audit`: audit citation consistency, numbers, terminology, and cross-references
- `release-governance`: prepare release, rebuttal, artifact, and claim packets with ref-artifact-gate controls
- `style`: check and safely fix common US spellings when British English is required
- `logic-review`: review paragraph flow and transition issues
- `verify-refs`: validate BibTeX and reference metadata
- `human-eval-handoff-repair`: validate, repair, and map human-evaluation handoff packages and filled annotation CSVs
- `peer-review`: review another author's manuscript as an external reviewer
- `self-review`: review your own manuscript with clean-room source-boundary controls
- `progress`: show reading, writing, and coverage progress
- `export`: export chapters and notes to Word documents

## Workspace Assumptions

The skills expect a writing project with these directories when relevant:

- `chapters/`
- `literature/`
- `literature/reading_notes/`
- `release/`
- `final_output/`
- `codex_outputs/` for generated handoff-repair reports when no output directory is specified

Script-backed skills use helper scripts bundled inside the individual skill directories, so the plugin can run without copying the repository-level `scripts/` directory into a user's project.

## Publishing Assets

The Codex manifest references these local PNG assets under `assets/`:

- `icon.png`
- `logo.png`

Claude Code's plugin schema has no icon or logo field, so these assets apply to the
Codex package only. Historical screenshots remain in the repository but are not part
of the no-UI directory manifest. Run `make plugin-check` before publishing to validate
both manifests, both marketplace entries, bundled helpers, release metadata, and asset
paths.

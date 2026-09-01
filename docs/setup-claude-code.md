# Setup: Claude Code

Two routes are supported.

- **Plugin** — install the 20 skills into Claude Code and use them in any
  project. No clone required.
- **From source** — clone the repository to also get the validators, examples,
  templates, and project scaffolding, or to contribute.

## Prerequisites

- [Claude Code](https://claude.ai/code) installed and authenticated
- Python 3.9+ on `PATH` for the script-backed skills (`audit`, `style`,
  `logic-review`, `verify-refs`, `export`, and the packet validators)
- `pandoc` and `python-docx` for `export`

## Route 1: install the plugin (recommended)

From inside Claude Code:

```
/plugin marketplace add cosmosapjw-quantum/academic-writing-toolkit
/plugin install academic-writing-toolkit@academic-writing-toolkit
```

Or from a shell:

```bash
claude plugin marketplace add cosmosapjw-quantum/academic-writing-toolkit \
  --sparse .claude-plugin plugins/academic-writing-toolkit

claude plugin install academic-writing-toolkit@academic-writing-toolkit
claude plugin list
claude plugin details academic-writing-toolkit
```

`--sparse` limits the checkout to the two directories the plugin needs. Drop it
if you would rather fetch the whole repository.

`claude plugin details` should report 20 skills and no commands, agents, hooks,
or MCP servers. Restart Claude Code to load them.

The Claude Code plugin marketplace is published from the fork
`cosmosapjw-quantum/academic-writing-toolkit`. The from-source route below uses
the upstream repository.

### Update and remove

```bash
claude plugin marketplace update academic-writing-toolkit
claude plugin update academic-writing-toolkit
claude plugin uninstall academic-writing-toolkit
claude plugin marketplace remove academic-writing-toolkit
```

## Route 2: use the repository from source

```bash
git clone https://github.com/yha9806/academic-writing-toolkit.git my-thesis
cd my-thesis
make setup
make doctor
claude
```

`make setup` sets `git config core.fileMode false` (avoids mode-bit noise
commits), regenerates `AGENTS.md` and `GEMINI.md` from `CLAUDE.md`, and runs
`make doctor`. If `make doctor` reports anything red, run `make repair` to fix
what it can.

Skills are auto-discovered from `.claude/skills/`. Use `git clone`, not GitHub's
**Download ZIP** — the toolkit uses symlinks under `.agents/skills/` so other
local agents discover the same canonical skills.

## Skill invocation

| Route | Form | Example |
|---|---|---|
| Plugin | namespaced by plugin name | `/academic-writing-toolkit:read` |
| From source | project skill, bare name | `/read` |

Either way Claude can also select a skill from a plain-language request, for
example "read this paper and extract thesis connections".

Do not use both routes in the same project unless you want the catalogue loaded
twice.

## Available skills

| Skill | Purpose |
|-------|---------|
| `read` | Read PDFs page by page with key arguments, a terms glossary, and thesis connections |
| `note` | Record reading notes to the structured notes file |
| `verify` | Fact-check dates, names, events, and citations met while reading |
| `map` | Show or update which sources support which chapters and arguments |
| `evidence-review` | Build evidence-controlled reviews and gap maps with source-status labels, claim registers, citation-role plans, traceability tables, and overclaim audits |
| `argument-governance` | Build and audit intent, gap-contribution alignment, hierarchical claims, evidence balance, limitations, and reviewer attack surfaces |
| `integrate` | Map reading notes to chapters and integrate key arguments into the manuscript |
| `thesis-control` | Keep AI-assisted thesis edits bounded with spine cards, edit contracts, drift audits, revision escalation, and human gates |
| `manuscript-reframe` | Reframe report-like drafts into paper-form scientific arguments with gap, contribution chain, results narrative, figure and table roles, and submission blockers |
| `revision-escalation` | Stop repeated failed revisions after three unsatisfactory edits and diagnose specification, structure, evidence, or version-contamination problems |
| `peer-review` | Review another author's manuscript as an external reviewer, without rewriting it or using private author context |
| `self-review` | Review your own manuscript with clean-room controls that exclude chat memory, unstated assumptions, and unlisted local notes as evidence |
| `audit` | Check a draft before submission for inconsistent numbers, terminology, cross-references, or citation problems |
| `release-governance` | Prepare release, rebuttal, artifact, and claim packets with ref, artifact, evidence-state, and gate controls |
| `human-eval-handoff-repair` | Validate, repair, and map human-evaluation handoff packages and filled annotation CSVs across package versions |
| `style` | Check British English consistency and apply safe mechanical spelling fixes |
| `logic-review` | Review paragraph-level flow, transitions, and argument continuity before editing |
| `verify-refs` | Check BibTeX records for missing fields, malformed identifiers, duplicate keys, or metadata mismatches |
| `progress` | Show reading and writing progress: sources read, chapters completed, word counts, and coverage gaps |
| `export` | Convert chapters and reading notes to Word documents and package them for submission |

Detailed guides live in [the skills guide](skills/README.md).

## Verify

Ask Claude: "What skills are available?"

You should see the full catalogue, including `evidence-review` and
`release-governance`.

## Customise

The from-source route ships a `CLAUDE.md` you can edit to set:

- word count targets per chapter
- reading pace limits, for example maximum pages per session
- directory paths for literature and chapters
- citation style and British English policy

Then run `make sync` to regenerate `AGENTS.md` and `GEMINI.md`.

On the plugin route there is no repository `CLAUDE.md`. Put the same settings in
your own project's `CLAUDE.md`; the skills read it where it matters, for example
`audit` reads the `Citation style:` line.

## Global installation without the plugin (optional)

If you already have the repository cloned and want the skills in every project
without using the plugin:

```bash
cp -r .claude/skills/* ~/.claude/skills/
```

Do not combine this with the plugin install. `~/.claude/skills/` is itself
auto-loaded, so you would get every skill twice — once bare and once as
`/academic-writing-toolkit:<skill>`.

## Usage examples

```
/academic-writing-toolkit:read literature/my-paper.pdf
/academic-writing-toolkit:note
/academic-writing-toolkit:map
/academic-writing-toolkit:evidence-review
/academic-writing-toolkit:audit
/academic-writing-toolkit:verify-refs references.bib
/academic-writing-toolkit:export chapters en-only
```

On the from-source route, drop the `academic-writing-toolkit:` prefix.

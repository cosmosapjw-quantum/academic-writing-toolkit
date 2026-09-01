# Plugin Publishing Checklist

Use this checklist before publishing or sharing the Academic Writing Toolkit plugin.
One generated `skills/` tree serves two hosts:

| Host | Manifest | Marketplace |
|---|---|---|
| Claude Code | `plugins/academic-writing-toolkit/.claude-plugin/plugin.json` | `.claude-plugin/marketplace.json` |
| Codex | `plugins/academic-writing-toolkit/.codex-plugin/plugin.json` | `.agents/plugins/marketplace.json` |

The Codex sections target the official OpenAI Codex plugin package format described in
the OpenAI Developers Codex plugin docs.

## OpenAI Directory Status

OpenAI now operates one Plugins Directory shared by ChatGPT and Codex. A package may
contain skills, an MCP app, or both. Submission, review, and publication are separate
states: a locally valid package or deployed MCP server is not automatically listed.

References:

- https://developers.openai.com/plugins/build/plugins
- https://developers.openai.com/plugins/deploy/submission
- https://platform.openai.com/plugins

## Claude Code Distribution Status

Claude Code plugins install from any Git repository that exposes
`.claude-plugin/marketplace.json` at its root. There is no central review queue:
publishing means pushing the manifests and telling users the marketplace source.
Listing in Anthropic's `claude-plugins-official` marketplace is a separate, optional
submission.

The Claude Code marketplace is served from the fork
`cosmosapjw-quantum/academic-writing-toolkit`:

```
/plugin marketplace add cosmosapjw-quantum/academic-writing-toolkit
/plugin install academic-writing-toolkit@academic-writing-toolkit
```

## Required Local Checks

Run these from the repository root:

```bash
make plugin-sync
make plugin-check
make chatgpt-app-check
npm audit --prefix apps/chatgpt-academic-writing-toolkit --omit=dev --audit-level=high
make test
```

`make plugin-sync` regenerates `plugins/academic-writing-toolkit/skills/` from the
canonical `.claude/skills/` directory. `make plugin-check` validates both manifests,
both marketplace entries, bundled helper scripts, SemVer, directory text limits,
HTTPS URLs, icon assets, cross-manifest version agreement, and sync state.

Run the Claude Code CLI schema check by hand at least once per release:

```bash
claude plugin validate ./plugins/academic-writing-toolkit --strict
claude plugin validate . --strict
```

`make plugin-check` runs both automatically when the `claude` CLI is on `PATH`, and
warns and skips when it is not, because CI has no `claude` binary. Set
`AWT_SKIP_CLAUDE_CLI_VALIDATE=1` to force the skip locally. Two invocations are
required: `claude plugin validate <dir>` prefers a marketplace manifest when one is
present, so validating the repository root does not validate the plugin.

## Claude Code Manifest Review

Check `plugins/academic-writing-toolkit/.claude-plugin/plugin.json` for:

- `name`: `academic-writing-toolkit`, kebab-case, equal to the directory name
- `version`: current release version, SemVer, equal to the Codex manifest
  (`claude plugin validate --strict` fails when `version` is absent)
- `description`, `author.name`, `license: MIT`, and a non-empty `keywords` list
- `homepage` and `repository`: the fork that serves this marketplace
- no `interface` block; that is Codex-only
- no `skills` override: the runtime already scans `./skills/`, and a declared path is
  additive rather than a replacement, so declaring it risks loading all 20 skills twice
- `.claude-plugin/` contains `plugin.json` and nothing else, in particular no
  component directories
- no `CLAUDE.md` at the plugin root; `--strict` warns on it

## Claude Code Marketplace Review

Check `.claude-plugin/marketplace.json` for:

- `name`: `academic-writing-toolkit`, kebab-case
- `owner.name` present
- exactly one `academic-writing-toolkit` entry
- `source`: `./plugins/academic-writing-toolkit` as a plain relative string, not the
  Codex `{"source": "local", "path": ...}` object
- `category`: `productivity`, lowercase
- no `policy` block; that is Codex-only
- entry `version` omitted so `plugin.json` stays the single source of truth. If you do
  pin it, it must equal `plugin.json`, which `make plugin-check` enforces

## Codex Manifest Review

Check `plugins/academic-writing-toolkit/.codex-plugin/plugin.json` for:

- `name`: `academic-writing-toolkit`
- `version`: current release version
- `repository`, `homepage`, and `websiteURL`: public repository URLs
- `privacyPolicyURL`: `docs/privacy.md` on the public default branch
- `termsOfServiceURL`: `docs/terms.md` on the public default branch
- `supportURL`: public issue tracker
- `shortDescription`: no more than 30 characters
- `composerIcon` and `logo`: PNG paths under `./assets/`
- `defaultPrompt`: no more than three short starter prompts
- no `screenshots` for this no-UI, skills-only package
- no `apps` or `mcpServers` in the skills-only ZIP

OpenAI's published plugin manifest example uses these same field groups: package metadata, bundled component paths, and the `interface` install-surface metadata.

## Codex Marketplace Review

Check `.agents/plugins/marketplace.json` for:

- one `academic-writing-toolkit` entry
- `source.path`: `./plugins/academic-writing-toolkit`
- `policy.installation`: `AVAILABLE`
- `policy.authentication`: `ON_INSTALL`
- `category`: `Productivity`

This repo marketplace is for local, repo, team, or personal distribution. It is not an official OpenAI Plugin Directory submission by itself.

## Asset Review

Current manifest assets live in `plugins/academic-writing-toolkit/assets/`:

- `icon.png`
- `logo.png`

Historical screenshots remain in the repository but are excluded from the skills-only
manifest because this package has no custom UI.

## Submission Packet

Keep `docs/openai-codex-plugin-submission.md` current. Before submission:

- deploy and live-test the MCP endpoint
- scan the endpoint in OpenAI Platform and confirm all five tool annotations
- keep exactly five positive and three negative App test cases
- use the portal's **With MCP** flow and production URL for the public submission;
  use a real Developer Mode connection ID only when building a local combined package
- confirm publisher identity and policy declarations in the portal
- upload the exact reviewed package, then submit it for review

## Release Notes

Before publishing a new version:

- update `version` in both `.claude-plugin/plugin.json` and
  `.codex-plugin/plugin.json`, plus the Claude marketplace entry if you pinned it
- run `make plugin-sync`
- run `make plugin-check`
- run `make chatgpt-app-check` and the production dependency audit
- run `make test`
- commit the plugin/App package and supporting docs together
- deploy and verify before changing any document from “target” to “live”

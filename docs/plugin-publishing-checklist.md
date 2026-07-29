# Codex Plugin Publishing Checklist

Use this checklist before submitting or sharing the Academic Writing Toolkit Codex plugin. This checklist targets the official OpenAI Codex plugin package format described in the OpenAI Developers Codex plugin docs.

## Official Directory Status

OpenAI now operates one Plugins Directory shared by ChatGPT and Codex. A package may
contain skills, an MCP app, or both. Submission, review, and publication are separate
states: a locally valid package or deployed MCP server is not automatically listed.

References:

- https://developers.openai.com/plugins/build/plugins
- https://developers.openai.com/plugins/deploy/submission
- https://platform.openai.com/plugins

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
canonical `.claude/skills/` directory. `make plugin-check` validates the skills-only
manifest, marketplace entry, bundled helper scripts, SemVer, directory text limits,
HTTPS URLs, icon assets, and sync state.

## Official Manifest Review

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

## Marketplace Review For Testing

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

- update the manifest `version`
- run `make plugin-sync`
- run `make plugin-check`
- run `make chatgpt-app-check` and the production dependency audit
- run `make test`
- commit the plugin/App package and supporting docs together
- deploy and verify before changing any document from “target” to “live”

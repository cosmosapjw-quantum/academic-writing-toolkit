#!/usr/bin/env bash
# scripts/check-plugin.sh
#
# Validates the local Claude Code and Codex plugin packages before publishing or
# marketplace use. One skills/ tree serves both hosts, so both manifests are
# checked together and their versions must agree.
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/lib.sh"

PLUGIN_ROOT="$REPO_ROOT/plugins/academic-writing-toolkit"
PLUGIN_JSON="$PLUGIN_ROOT/.codex-plugin/plugin.json"
MARKETPLACE_JSON="$REPO_ROOT/.agents/plugins/marketplace.json"
CLAUDE_PLUGIN_JSON="$PLUGIN_ROOT/.claude-plugin/plugin.json"
CLAUDE_MARKETPLACE_JSON="$REPO_ROOT/.claude-plugin/marketplace.json"

find_python() {
    if [[ -n "${PYTHON:-}" ]]; then
        "$PYTHON" -c 'import sys' >/dev/null 2>&1 || die "PYTHON is set but not usable: $PYTHON"
        printf '%s\n' "$PYTHON"
        return 0
    fi
    local candidate
    for candidate in python3 python; do
        if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c 'import sys' >/dev/null 2>&1; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    die "missing usable Python interpreter; set PYTHON=/path/to/python"
}

PYTHON_BIN="$(find_python)"

[[ -f "$PLUGIN_JSON" ]] || die "missing plugin manifest: $PLUGIN_JSON"
[[ -f "$MARKETPLACE_JSON" ]] || die "missing marketplace manifest: $MARKETPLACE_JSON"
[[ -f "$CLAUDE_PLUGIN_JSON" ]] || die "missing Claude plugin manifest: $CLAUDE_PLUGIN_JSON"
[[ -f "$CLAUDE_MARKETPLACE_JSON" ]] || die "missing Claude marketplace manifest: $CLAUDE_MARKETPLACE_JSON"

PYTHON="$PYTHON_BIN" bash "$SCRIPT_DIR/sync-plugin.sh" --check >/dev/null

"$PYTHON_BIN" -m json.tool "$PLUGIN_JSON" >/dev/null
"$PYTHON_BIN" -m json.tool "$MARKETPLACE_JSON" >/dev/null
"$PYTHON_BIN" -m json.tool "$CLAUDE_PLUGIN_JSON" >/dev/null
"$PYTHON_BIN" -m json.tool "$CLAUDE_MARKETPLACE_JSON" >/dev/null

"$PYTHON_BIN" - "$PLUGIN_JSON" "$MARKETPLACE_JSON" <<'PY'
import json
import re
import sys
import unicodedata
from pathlib import Path
from urllib.parse import urlparse

plugin_path = Path(sys.argv[1])
marketplace_path = Path(sys.argv[2])
plugin = json.loads(plugin_path.read_text(encoding="utf-8"))
marketplace = json.loads(marketplace_path.read_text(encoding="utf-8"))

name = "academic-writing-toolkit"
if plugin.get("name") != name:
    raise SystemExit("plugin name must be academic-writing-toolkit")
if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,63}", name):
    raise SystemExit("plugin name must satisfy final directory format and length limits")
version = plugin.get("version", "")
if not re.fullmatch(
    r"(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)"
    r"(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?",
    version,
):
    raise SystemExit("plugin version must be valid SemVer")
if len(version) > 64:
    raise SystemExit("plugin version must contain at most 64 characters")
description = plugin.get("description")
if not isinstance(description, str) or not description or len(description) > 1024:
    raise SystemExit("plugin description must contain 1-1024 characters")
author = plugin.get("author")
if not isinstance(author, dict):
    raise SystemExit("plugin author must be an object")
author_name = author.get("name")
if (
    not isinstance(author_name, str)
    or not author_name
    or "\n" in author_name
    or len(author_name) > 120
):
    raise SystemExit("plugin author.name must contain 1-120 single-line characters")
if plugin.get("skills") != "./skills/":
    raise SystemExit("plugin skills path must be ./skills/")
if "hooks" in plugin or "mcpServers" in plugin or "apps" in plugin:
    raise SystemExit("plugin manifest should not reference absent hooks, MCP, or app manifests")

interface = plugin.get("interface")
if not isinstance(interface, dict):
    raise SystemExit("plugin interface must be an object")
for field in [
    "displayName",
    "shortDescription",
    "longDescription",
    "developerName",
    "category",
    "defaultPrompt",
    "websiteURL",
    "supportURL",
    "privacyPolicyURL",
    "termsOfServiceURL",
    "composerIcon",
    "logo",
]:
    if not interface.get(field):
        raise SystemExit(f"plugin interface.{field} is required")
short_description = interface["shortDescription"]
if (
    not isinstance(short_description, str)
    or not short_description
    or "\n" in short_description
    or len(short_description) > 30
):
    raise SystemExit(
        "plugin interface.shortDescription must contain 1-30 single-line characters"
    )

display_name = interface["displayName"]
if (
    not isinstance(display_name, str)
    or not display_name
    or "\n" in display_name
    or len(display_name) > 30
):
    raise SystemExit(
        "plugin interface.displayName must contain 1-30 single-line characters"
    )

long_description = interface["longDescription"]
if (
    not isinstance(long_description, str)
    or not long_description
    or len(long_description) > 4000
):
    raise SystemExit("plugin interface.longDescription must contain 1-4000 characters")

developer_name = interface["developerName"]
if (
    not isinstance(developer_name, str)
    or not developer_name
    or "\n" in developer_name
    or len(developer_name) > 80
):
    raise SystemExit(
        "plugin interface.developerName must contain 1-80 single-line characters"
    )
if developer_name != author_name:
    raise SystemExit("plugin author.name and interface.developerName must match")

allowed_categories = {
    "Productivity",
    "Creativity",
    "Developer Tools",
    "Business & Operations",
    "Data & Analytics",
    "Communication",
    "Education & Research",
    "Security",
    "Finance",
    "Healthcare",
    "Travel",
    "Entertainment",
    "Other",
}
if interface["category"] not in allowed_categories:
    raise SystemExit("plugin interface.category is not supported")

capabilities = interface.get("capabilities")
if not isinstance(capabilities, list) or len(capabilities) > 20:
    raise SystemExit("plugin interface.capabilities must contain at most 20 entries")
for capability in capabilities:
    if (
        not isinstance(capability, str)
        or not capability
        or "\n" in capability
        or len(capability) > 120
    ):
        raise SystemExit(
            "each plugin capability must contain 1-120 single-line characters"
        )

default_prompts = interface["defaultPrompt"]
if not isinstance(default_prompts, list) or not 1 <= len(default_prompts) <= 3:
    raise SystemExit("plugin interface.defaultPrompt must contain 1-3 entries")
normalised_prompts = set()
for prompt in default_prompts:
    if (
        not isinstance(prompt, str)
        or not prompt
        or "\n" in prompt
        or len(prompt) > 128
        or "@" in prompt
    ):
        raise SystemExit(
            "each default prompt must be single-line, mention-free, and 1-128 characters"
        )
    normalised = " ".join(unicodedata.normalize("NFKC", prompt).split()).casefold()
    if normalised in normalised_prompts:
        raise SystemExit("plugin default prompts must be unique after normalisation")
    normalised_prompts.add(normalised)

for field in [
    "homepage",
    "repository",
]:
    value = plugin.get(field)
    parsed = urlparse(value) if isinstance(value, str) else None
    if (
        not parsed
        or parsed.scheme != "https"
        or not parsed.netloc
        or parsed.username
        or parsed.password
    ):
        raise SystemExit(f"plugin {field} must be an HTTPS URL")

author_url = author.get("url")
author_url_parsed = urlparse(author_url) if isinstance(author_url, str) else None
if (
    not author_url_parsed
    or author_url_parsed.scheme != "https"
    or not author_url_parsed.netloc
    or author_url_parsed.username
    or author_url_parsed.password
    or len(author_url) > 1024
):
    raise SystemExit("plugin author.url must be a credential-free HTTPS URL")

for field in [
    "websiteURL",
    "supportURL",
    "privacyPolicyURL",
    "termsOfServiceURL",
]:
    value = interface[field]
    parsed = urlparse(value) if isinstance(value, str) else None
    if (
        not parsed
        or parsed.scheme != "https"
        or not parsed.netloc
        or parsed.username
        or parsed.password
        or len(value) > 1024
    ):
        raise SystemExit(f"plugin interface.{field} must be an HTTPS URL")

brand_color = interface.get("brandColor")
if brand_color is not None and not re.fullmatch(r"#[0-9A-Fa-f]{6}", brand_color):
    raise SystemExit("plugin interface.brandColor must be a six-digit hex colour")

for field in ["composerIcon", "logo"]:
    value = interface[field]
    if not isinstance(value, str) or not value.startswith("./assets/") or not value.endswith(".png"):
        raise SystemExit(f"plugin interface.{field} must point to a PNG under ./assets/")

if "screenshots" in interface:
    raise SystemExit("skills-only plugins must not declare screenshots")

entries = [entry for entry in marketplace.get("plugins", []) if entry.get("name") == name]
if len(entries) != 1:
    raise SystemExit("marketplace must contain exactly one academic-writing-toolkit entry")
entry = entries[0]
if entry.get("source", {}).get("path") != "./plugins/academic-writing-toolkit":
    raise SystemExit("marketplace source.path is incorrect")
policy = entry.get("policy", {})
if policy.get("installation") != "AVAILABLE":
    raise SystemExit("marketplace policy.installation must be AVAILABLE")
if policy.get("authentication") != "ON_INSTALL":
    raise SystemExit("marketplace policy.authentication must be ON_INSTALL")
if not entry.get("category"):
    raise SystemExit("marketplace category is required")
PY

"$PYTHON_BIN" - "$PLUGIN_ROOT" "$CLAUDE_PLUGIN_JSON" "$CLAUDE_MARKETPLACE_JSON" "$PLUGIN_JSON" <<'PY'
import json
import re
import sys
from pathlib import Path
from urllib.parse import urlparse

plugin_root = Path(sys.argv[1])
claude_plugin_path = Path(sys.argv[2])
claude_marketplace_path = Path(sys.argv[3])
codex_plugin_path = Path(sys.argv[4])

plugin = json.loads(claude_plugin_path.read_text(encoding="utf-8"))
marketplace = json.loads(claude_marketplace_path.read_text(encoding="utf-8"))
codex_plugin = json.loads(codex_plugin_path.read_text(encoding="utf-8"))

name = "academic-writing-toolkit"
semver = re.compile(
    r"(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)"
    r"(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?"
)
kebab = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*")


def require_https(value, label):
    parsed = urlparse(value) if isinstance(value, str) else None
    if (
        not parsed
        or parsed.scheme != "https"
        or not parsed.netloc
        or parsed.username
        or parsed.password
        or len(value) > 1024
    ):
        raise SystemExit("%s must be a credential-free HTTPS URL" % label)


# Only plugin.json may live in .claude-plugin/; component directories placed
# there are silently ignored by the runtime, so reject them here.
claude_dir = claude_plugin_path.parent
if claude_dir.name != ".claude-plugin":
    raise SystemExit("Claude manifest must live in .claude-plugin/")
for child in sorted(claude_dir.iterdir()):
    if child.is_dir():
        raise SystemExit(
            "no directories are allowed inside .claude-plugin/: %s" % child.name
        )
    if child.name != "plugin.json":
        raise SystemExit(
            ".claude-plugin/ must contain only plugin.json, found: %s" % child.name
        )

allowed_plugin_fields = {
    "$schema",
    "name",
    "displayName",
    "version",
    "description",
    "author",
    "homepage",
    "repository",
    "license",
    "keywords",
    "defaultEnabled",
    "dependencies",
    "metadata",
    "commands",
    "agents",
    "skills",
    "hooks",
    "mcpServers",
    "lspServers",
    "outputStyles",
    "themes",
    "workflows",
    "userConfig",
    "evals",
}
unknown = sorted(set(plugin) - allowed_plugin_fields)
if unknown:
    raise SystemExit("unknown Claude plugin manifest fields: " + ", ".join(unknown))
if "interface" in plugin:
    raise SystemExit("Claude plugin manifest must not carry the Codex interface block")
if plugin.get("name") != name:
    raise SystemExit("Claude plugin name must be academic-writing-toolkit")
if not kebab.fullmatch(plugin["name"]):
    raise SystemExit("Claude plugin name must be kebab-case")
version = plugin.get("version", "")
if not isinstance(version, str) or not semver.fullmatch(version):
    raise SystemExit("Claude plugin version must be valid SemVer")
description = plugin.get("description")
if not isinstance(description, str) or not description.strip():
    raise SystemExit("Claude plugin description is required")
author = plugin.get("author")
if (
    not isinstance(author, dict)
    or not isinstance(author.get("name"), str)
    or not author["name"].strip()
):
    raise SystemExit("Claude plugin author.name is required")
for field in ["homepage", "repository"]:
    require_https(plugin.get(field), "Claude plugin " + field)
if plugin.get("license") != "MIT":
    raise SystemExit("Claude plugin license must be MIT")
keywords = plugin.get("keywords")
if not isinstance(keywords, list) or not keywords:
    raise SystemExit("Claude plugin keywords must be a non-empty list")

# The runtime always scans <plugin root>/skills/; a declared skills path is
# additive, so it must resolve rather than replace that default.
declared_skills = plugin.get("skills")
if declared_skills is None:
    if not (plugin_root / "skills").is_dir():
        raise SystemExit("default skills/ directory is missing from the plugin root")
else:
    entries = [declared_skills] if isinstance(declared_skills, str) else declared_skills
    if not isinstance(entries, list) or not entries:
        raise SystemExit("Claude plugin skills must be a path or a list of paths")
    for item in entries:
        if not isinstance(item, str):
            raise SystemExit("each Claude plugin skills entry must be a string path")
        if item.startswith("/") or ".." in Path(item).parts:
            raise SystemExit("Claude plugin skills paths must stay inside the plugin root")
        if not (plugin_root / item).is_dir():
            raise SystemExit("declared Claude plugin skills path does not resolve: " + item)

allowed_marketplace_fields = {
    "$schema",
    "name",
    "description",
    "owner",
    "metadata",
    "plugins",
    "renames",
}
unknown = sorted(set(marketplace) - allowed_marketplace_fields)
if unknown:
    raise SystemExit("unknown Claude marketplace fields: " + ", ".join(unknown))
if marketplace.get("name") != name:
    raise SystemExit("Claude marketplace name must be academic-writing-toolkit")
if not kebab.fullmatch(marketplace["name"]):
    raise SystemExit("Claude marketplace name must be kebab-case")
owner = marketplace.get("owner")
if (
    not isinstance(owner, dict)
    or not isinstance(owner.get("name"), str)
    or not owner["name"].strip()
):
    raise SystemExit("Claude marketplace owner.name is required")
if owner.get("url") is not None:
    require_https(owner.get("url"), "Claude marketplace owner.url")

market_entries = marketplace.get("plugins")
if not isinstance(market_entries, list) or len(market_entries) != 1:
    raise SystemExit("Claude marketplace must declare exactly one plugin entry")
entry = market_entries[0]
if entry.get("name") != name:
    raise SystemExit("Claude marketplace entry name must be academic-writing-toolkit")
if entry.get("source") != "./plugins/academic-writing-toolkit":
    raise SystemExit(
        "Claude marketplace entry source must be ./plugins/academic-writing-toolkit"
    )
if "policy" in entry:
    raise SystemExit("Claude marketplace entries must not carry the Codex policy block")
entry_description = entry.get("description")
if not isinstance(entry_description, str) or not entry_description.strip():
    raise SystemExit("Claude marketplace entry description is required")
if entry.get("category") != "productivity":
    raise SystemExit("Claude marketplace entry category must be productivity")
market_root = claude_marketplace_path.parent.parent
if not (market_root / entry["source"] / ".claude-plugin" / "plugin.json").is_file():
    raise SystemExit("Claude marketplace source does not resolve to a plugin root")

codex_version = codex_plugin.get("version")
if version != codex_version:
    raise SystemExit(
        "version mismatch: Claude manifest %s vs Codex manifest %s"
        % (version, codex_version)
    )
entry_version = entry.get("version")
if entry_version is not None and entry_version != version:
    raise SystemExit(
        "Claude marketplace entry version %s does not match plugin.json %s"
        % (entry_version, version)
    )
PY

"$PYTHON_BIN" - "$PLUGIN_ROOT" "$PLUGIN_JSON" <<'PY'
import json
import struct
import sys
from pathlib import Path

plugin_root = Path(sys.argv[1])
plugin = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
interface = plugin["interface"]
assets = [interface["composerIcon"], interface["logo"]]

for asset in assets:
    relative_asset = asset[2:] if asset.startswith("./") else asset
    path = plugin_root / relative_asset
    if not path.is_file():
        raise SystemExit(f"missing asset: {asset}")
    data = path.read_bytes()
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise SystemExit(f"asset is not a PNG: {asset}")
    if len(data) < 24 or data[12:16] != b"IHDR":
        raise SystemExit(f"asset has invalid PNG header: {asset}")
    width, height = struct.unpack(">II", data[16:24])
    if width < 64 or height < 64:
        raise SystemExit(f"asset is too small: {asset}")
PY

"$PYTHON_BIN" - "$PLUGIN_ROOT" <<'PY'
import ast
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    yaml = None

plugin_root = Path(sys.argv[1])
skill_paths = sorted((plugin_root / "skills").glob("*/SKILL.md"))
if len(skill_paths) != 20:
    raise SystemExit(f"expected 20 plugin skills, observed {len(skill_paths)}")

for path in skill_paths:
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---\n"):
        raise SystemExit(f"missing YAML frontmatter: {path}")
    try:
        frontmatter = text.split("---", 2)[1]
    except IndexError as error:
        raise SystemExit(f"unterminated YAML frontmatter: {path}") from error

    if yaml is not None:
        try:
            metadata = yaml.safe_load(frontmatter)
        except yaml.YAMLError as error:
            raise SystemExit(f"invalid YAML frontmatter in {path}: {error}") from error
    else:
        metadata = {}
        for line_number, line in enumerate(frontmatter.splitlines(), start=2):
            if not line.strip():
                continue
            if line[:1].isspace() or ":" not in line:
                raise SystemExit(
                    f"unsupported YAML frontmatter at {path}:{line_number}"
                )
            key, raw_value = line.split(":", 1)
            raw_value = raw_value.strip()
            if raw_value.startswith(("'", '"')):
                try:
                    value = ast.literal_eval(raw_value)
                except (SyntaxError, ValueError) as error:
                    raise SystemExit(
                        f"invalid quoted YAML scalar at {path}:{line_number}"
                    ) from error
            else:
                if ": " in raw_value:
                    raise SystemExit(
                        f"ambiguous unquoted YAML scalar at {path}:{line_number}"
                    )
                value = raw_value
            metadata[key.strip()] = value

    if not isinstance(metadata, dict):
        raise SystemExit(f"frontmatter must be a mapping: {path}")
    if metadata.get("name") != path.parent.name:
        raise SystemExit(f"skill name does not match directory: {path}")
    description = metadata.get("description")
    if not isinstance(description, str) or not description.strip():
        raise SystemExit(f"skill description is required: {path}")
PY

if grep -R "\[TODO\]\|TODO:" "$PLUGIN_ROOT" "$MARKETPLACE_JSON" "$CLAUDE_MARKETPLACE_JSON" >/dev/null; then
    die "plugin package contains TODO placeholders"
fi

for skill in argument-governance audit evidence-review export human-eval-handoff-repair integrate logic-review manuscript-reframe map note peer-review progress read release-governance revision-escalation self-review style thesis-control verify verify-refs; do
    [[ -f "$PLUGIN_ROOT/skills/$skill/SKILL.md" ]] || die "missing plugin skill: $skill"
done

"$PYTHON_BIN" "$PLUGIN_ROOT/skills/argument-governance/scripts/check_argument_governance.py" --help >/dev/null
"$PYTHON_BIN" "$PLUGIN_ROOT/skills/audit/scripts/audit-citations.py" --help >/dev/null
"$PYTHON_BIN" "$PLUGIN_ROOT/skills/style/scripts/audit-british-english.py" --help >/dev/null
"$PYTHON_BIN" "$PLUGIN_ROOT/skills/logic-review/scripts/audit-logic.py" --help >/dev/null
"$PYTHON_BIN" "$PLUGIN_ROOT/skills/verify-refs/scripts/verify-refs.py" --help >/dev/null
"$PYTHON_BIN" "$PLUGIN_ROOT/skills/export/scripts/convert_to_docx.py" --help >/dev/null
"$PYTHON_BIN" "$PLUGIN_ROOT/skills/evidence-review/scripts/check_review_package.py" --help >/dev/null
"$PYTHON_BIN" "$PLUGIN_ROOT/skills/release-governance/scripts/check_release_packet.py" --help >/dev/null
"$PYTHON_BIN" "$PLUGIN_ROOT/skills/thesis-control/scripts/check_thesis_control.py" --help >/dev/null
"$PYTHON_BIN" "$PLUGIN_ROOT/skills/thesis-control/scripts/scaffold_thesis_control.py" --help >/dev/null
"$PYTHON_BIN" "$PLUGIN_ROOT/skills/thesis-control/scripts/upgrade_thesis_control_revision_tracking.py" --help >/dev/null
"$PYTHON_BIN" "$PLUGIN_ROOT/skills/self-review/scripts/check_self_review_packet.py" --help >/dev/null

# Optional: the Claude Code CLI knows the authoritative manifest schema, but CI
# has no `claude` binary, so this stays a soft, skippable gate. Two invocations
# are required: `claude plugin validate <dir>` prefers a marketplace manifest
# when one is present, so validating the repo root does not validate the plugin.
if [[ "${AWT_SKIP_CLAUDE_CLI_VALIDATE:-0}" == "1" ]]; then
    warn "AWT_SKIP_CLAUDE_CLI_VALIDATE=1; skipped 'claude plugin validate --strict'"
elif command -v claude >/dev/null 2>&1; then
    claude plugin validate "$PLUGIN_ROOT" --strict >/dev/null \
        || die "claude plugin validate --strict failed for $PLUGIN_ROOT"
    claude plugin validate "$REPO_ROOT" --strict >/dev/null \
        || die "claude plugin validate --strict failed for $REPO_ROOT"
    ok "claude CLI strict validation passed"
else
    warn "claude CLI not found; skipped 'claude plugin validate --strict'"
fi

ok "plugin packages validate"

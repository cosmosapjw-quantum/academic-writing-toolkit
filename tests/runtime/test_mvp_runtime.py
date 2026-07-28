from __future__ import annotations

import base64
import hashlib
import tempfile
import unittest
from pathlib import Path

from awt.mvp import (
    MAX_AGENT_INPUT_TOKENS,
    MvpApplication,
    MvpError,
    SessionStore,
    WORKFLOWS,
    analyse_document,
    build_agent_prompt,
)
from awt.workflow_io import WorkflowAuthorityError, run_workflow


SOURCE = b"The conclusion proves universal effectiveness.\n"


def digest(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def empty_runner(_text: str, _workflow: str, _purpose: str) -> dict:
    return {
        "status": "pass",
        "summary": "No issue in this engineering fixture.",
        "issues": [],
        "evidence_boundaries": [],
        "required_materials": [],
        "limitations": ["Engineering fixture; not writing-effect evidence."],
    }


def replacement_runner(text: str, _workflow: str, _purpose: str) -> dict:
    original = SOURCE.decode().strip()
    if original not in text:
        raise AssertionError("source missing from model context")
    return {
        "status": "warn",
        "summary": "One overclaim needs author review.",
        "issues": [
            {
                "title": "Universal claim exceeds the reported material",
                "severity": "high",
                "verification_status": "manuscript_reported_only",
                "verification_check": {
                    "claim_dimension": "manuscript_text_only",
                    "kind": "manuscript_only",
                    "result": "not_checked",
                    "note": "Only the manuscript statement was inspected.",
                },
                "evidence": original,
                "source_refs": ["manuscript"],
                "evidence_trace": [
                    {
                        "source_ref": "manuscript",
                        "locator": "Conclusion sentence",
                        "relationship": "supports",
                        "note": "The sentence makes a universal claim.",
                    }
                ],
                "explanation": "No supplied material supports universality.",
                "recommended_action": "Ask the author to narrow or add evidence.",
                "action_options": [
                    {
                        "option_id": "narrow_claim",
                        "label": "Narrow now",
                        "action": "Limit the wording to the observed setting.",
                        "tradeoff": "Safer but less general.",
                        "canonical": False,
                    }
                ],
                "replacement": {
                    "original_text": original,
                    "replacement_text": (
                        "The reported material supports effectiveness in this setting."
                    ),
                    "rationale": "Match wording to the supplied evidence.",
                },
            }
        ],
        "evidence_boundaries": ["Only manuscript text was inspected."],
        "required_materials": ["Comparative evidence for a broader claim."],
        "limitations": ["Engineering fixture; not writing-effect evidence."],
    }


class LeanRuntimeTests(unittest.TestCase):
    def test_five_workflows_use_lean_prompt_and_keep_source_read_only(self):
        for workflow_id in WORKFLOWS:
            with self.subTest(workflow_id=workflow_id):
                result = analyse_document(
                    SOURCE,
                    "paper.md",
                    workflow_id,
                    "preprint",
                    runner=empty_runner,
                )
                profile = result["runtime_instruction_profile"]
                self.assertTrue(result["source_unchanged"])
                self.assertFalse(result["write_performed"])
                self.assertEqual(profile["contract"], "lean-runtime-v1")
                self.assertFalse(profile["full_skill_injected"])
                self.assertLessEqual(
                    profile["prompt_plus_schema_estimate"]["tokens"],
                    MAX_AGENT_INPUT_TOKENS,
                )

    def test_prompt_does_not_embed_repository_skill(self):
        for workflow_id in WORKFLOWS:
            with self.subTest(workflow_id=workflow_id):
                prompt, profile = build_agent_prompt(
                    "<manuscript>Public-safe fixture.</manuscript>",
                    workflow_id,
                    "camera_ready",
                )
                self.assertIn("<workflow-card>", prompt)
                self.assertNotIn("AWT skill instructions", prompt)
                self.assertNotIn("<skill>", prompt)
                self.assertFalse(profile["full_skill_injected"])

    def test_oversized_non_bounded_request_stops_before_runner(self):
        calls = []

        def runner(*_args):
            calls.append(True)
            return empty_runner("", "", "")

        oversized = ("A bounded manuscript sentence. " * 12_000).encode()
        with self.assertRaisesRegex(MvpError, "超过 Lean Runtime"):
            analyse_document(
                oversized,
                "paper.md",
                "manuscript-reframe",
                "preprint",
                runner=runner,
            )
        self.assertEqual(calls, [])

    def test_restart_preserves_analysis_and_explicit_apply_copy(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "sessions"
            application = MvpApplication(
                runner=replacement_runner,
                store=SessionStore(root),
            )
            analysis = application.analyse(
                {
                    "filename": "paper.md",
                    "content_base64": base64.b64encode(SOURCE).decode(),
                    "workflow_id": "self-review",
                    "manuscript_purpose": "preprint",
                }
            )
            issue = analysis["result"]["issues"][0]
            decisions = [
                {
                    "issue_id": issue["issue_id"],
                    "decision": "accept",
                    "reason": "Synthetic runtime check.",
                    "modified_text": None,
                }
            ]
            saved = application.save(
                {
                    "session_id": analysis["session_id"],
                    "issue_decisions": decisions,
                    "review_revision": 1,
                }
            )
            restarted = MvpApplication(
                runner=lambda *_args: self.fail("restore reran the model"),
                store=SessionStore(root),
            )
            restored = restarted.restore({"session_id": analysis["session_id"]})
            self.assertEqual(restored["result"], analysis["result"])
            exported = restarted.export(
                {
                    "session_id": analysis["session_id"],
                    "issue_decisions": decisions,
                    "review_revision": saved["review_revision"],
                    "apply_copy_confirmed": True,
                }
            )
            copy = base64.b64decode(exported["copy_base64"])
            self.assertEqual(SOURCE, b"The conclusion proves universal effectiveness.\n")
            self.assertNotEqual(copy, SOURCE)
            self.assertFalse(exported["review"]["apply_source"])
            self.assertTrue(exported["review"]["source_unchanged"])

    def test_public_runtime_has_no_apply_source_mode(self):
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(temporary) / "paper.md"
            source.write_bytes(SOURCE)
            request = {
                "schema_version": 1,
                "request_id": "no-source-overwrite",
                "requested_at": "2026-07-28T22:00:00Z",
                "mode": "apply-source",
                "workflow_id": "self-review",
                "source": {"path": str(source), "sha256": digest(SOURCE)},
                "target_path": str(source),
                "authorisation": None,
            }
            with self.assertRaisesRegex(WorkflowAuthorityError, "invalid workflow mode"):
                run_workflow(request)
            self.assertEqual(source.read_bytes(), SOURCE)

    def test_packaged_assets_are_colocated_with_runtime(self):
        import awt.mvp

        root = Path(awt.mvp.__file__).resolve().parent
        self.assertTrue((root / "mvp_index.html").is_file())
        self.assertTrue((root / "demo-paper.md").is_file())


if __name__ == "__main__":
    unittest.main()

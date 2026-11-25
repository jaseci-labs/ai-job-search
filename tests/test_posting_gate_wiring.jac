"""Where the posting integrity gate (tools/posting_guard.jac) is wired beyond /apply
Step 0 and /rank Step 2: the archive, /interview, and the trust-boundary rules.

Why this test exists: a gate that only runs in one place is bypassed the moment
a posting reaches the workflow another way - from the archive in /interview, or
pasted by hand. These pins keep each entry point naming the gate, and keep the
archive free of the excerpts the gate removed (counts only), so a stripped
payload is never re-read by a later session.
"""

import re;

import unittest;

import from pathlib { Path }

glob REPO: any;

glob APPLY: any;

glob INTERVIEW: any;

glob RESEARCH: any;

with entry {
    REPO = Path(__file__).resolve().parent.parent;
    APPLY = REPO / ".claude" / "commands" / "apply.md";
    INTERVIEW = REPO / ".claude" / "commands" / "interview.md";
    RESEARCH = REPO / ".claude" / "skills" / "job-application-assistant" / "09-web-research.md";
}

class ArchiveWiring(unittest.TestCase) {
    def setUp -> any;

    def test_archive_stores_cleaned_text_with_counts_only -> any;
}

class InterviewWiring(unittest.TestCase) {
    def test_step1_gates_the_archived_posting_in_text_mode -> any;
}

"""The skill's own Step 1, /outcome's fresh-fetch archive and /interview's
    fetch fallback are the other places a posting enters; each names the gate."""
class OtherFrontDoors(unittest.TestCase) {
    def test_skill_step1_names_the_gate -> any;

    def test_outcome_fresh_fetch_is_gated -> any;

    def test_interview_fetch_fallback_is_gated -> any;

    def test_scratchpad_is_guarded_everywhere_the_gate_writes -> any;

    def test_fetch_agents_can_discover_installed_portals -> any;
}

class TrustBoundaryWiring(unittest.TestCase) {
    def test_09_trust_boundary_names_the_gate -> any;
}

with entry:__main__ {
    unittest.main();
}

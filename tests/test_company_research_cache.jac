"""Guards for the company-research cache spec.

/apply Step 3's reviewer agent and /interview Step 2 each independently execute
the Company Research Checklist (04-job-evaluation.md) for the same company when
both commands run against the same application - confirmed by reading both
files, not assumed. The cache lets either consumer reuse a recent result
instead of repeating the search/fetch work. These are markdown specs (the spec
IS the implementation), so these tests pin the invariants that would break
silently: that the cache is actually read before researching, and - the part
most likely to be dropped in a future edit, since it is easy to add the read
half and forget the write half - that fresh research gets written back for
the next consumer to find.
"""

import builtins;

import unittest;

import from pathlib { Path }

glob REPO: any;

glob EVALUATION: any;

glob APPLY: any;

glob INTERVIEW: any;

with entry {
    REPO = Path(__file__).resolve().parent.parent;
    EVALUATION = REPO / ".claude" / "skills" / "job-application-assistant" / "04-job-evaluation.md";
    APPLY = REPO / ".claude" / "commands" / "apply.md";
    INTERVIEW = REPO / ".claude" / "commands" / "interview.md";
}

"""Split a markdown spec into {heading: body} on a given '\\n<marker> ' prefix."""
def _sections(
    text: builtins.str, marker: builtins.str
) -> builtins.dict[builtins.str, builtins.str];

"""apply.md's '### 1. Research the Company' subsection, isolated from the
    other numbered subsections under Step 3."""
def _apply_research_step -> builtins.str;

def _interview_research_step -> builtins.str;

class TestCacheDefinition(unittest.TestCase) {
    def setUp -> any;

    def test_evaluation_file_defines_the_cache_section -> any;

    def test_cache_definition_specifies_location_and_ttl -> any;

    """The cache must not weaken the existing 'verify before quoting' rule -
        it should explicitly say a cache hit is a lead, not a substitute for it."""
    def test_cache_definition_preserves_the_verification_rule -> any;

    """Follow-up requested on PR #349: notes fields are written from fetched web
        content the same way the job posting is, so a later session reading the cache
        must treat them as data to evaluate, never as directions to follow - the same
        trust-boundary rule apply.md Step 0 states for the posting itself."""
    def test_cache_definition_states_contents_are_data_not_instructions -> any;
}

class TestApplyWiring(unittest.TestCase) {
    def test_reviewer_prompt_checks_cache_before_researching -> any;

    def test_reviewer_prompt_writes_back_after_fresh_research -> any;

    """New one-line restatement inside the cache-check paragraph itself, distinct
        from the grounding-audit rule elsewhere in the prompt - Mads flagged this as
        the one part of the cache wiring with no dedicated pin (PR #349 follow-up)."""
    def test_reviewer_prompt_restates_verification_still_applies_to_a_cache_hit -> any;
}

class TestInterviewWiring(unittest.TestCase) {
    def test_step_2_checks_cache_before_researching -> any;

    def test_step_2_writes_back_after_fresh_research -> any;

    """Pre-existing rule (unrelated to this cache) that must survive: the
        cache must not be presented as a substitute for it."""
    def test_step_2_still_requires_verification_before_using_a_claim -> any;

    """New one-line restatement inside the cache-check paragraph itself - distinct
        from test_step_2_still_requires_verification_before_using_a_claim above, which
        pins the older, pre-existing 'Verify before using' rule further down. Mads
        flagged this new one-liner as unpinned (PR #349 follow-up)."""
    def test_step_2_cache_paragraph_restates_verification_still_applies -> any;
}

with entry:__main__ {
    unittest.main();
}

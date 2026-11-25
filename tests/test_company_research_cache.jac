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

def _sections(
    text: builtins.str, marker: builtins.str
) -> builtins.dict[builtins.str, builtins.str];

def _apply_research_step -> builtins.str;

def _interview_research_step -> builtins.str;

class TestCacheDefinition(unittest.TestCase) {
    def setUp -> any;

    def test_evaluation_file_defines_the_cache_section -> any;

    def test_cache_definition_specifies_location_and_ttl -> any;

    def test_cache_definition_preserves_the_verification_rule -> any;

    def test_cache_definition_states_contents_are_data_not_instructions -> any;
}

class TestApplyWiring(unittest.TestCase) {
    def test_reviewer_prompt_checks_cache_before_researching -> any;

    def test_reviewer_prompt_writes_back_after_fresh_research -> any;

    def test_reviewer_prompt_restates_verification_still_applies_to_a_cache_hit -> any;
}

class TestInterviewWiring(unittest.TestCase) {
    def test_step_2_checks_cache_before_researching -> any;

    def test_step_2_writes_back_after_fresh_research -> any;

    def test_step_2_still_requires_verification_before_using_a_claim -> any;

    def test_step_2_cache_paragraph_restates_verification_still_applies -> any;
}

with entry:__main__ {
    unittest.main();
}

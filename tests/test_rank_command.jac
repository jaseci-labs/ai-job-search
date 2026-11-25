"""Guards for the /rank command spec.

The command is a markdown spec (the spec IS the implementation), so these
tests pin the invariants that would break silently: the header format that
lint_skills.jac enforces, and the persistence of scoring-agent gaps/strengths
into seen_jobs.json (previously computed in Step 2 and thrown away after
Step 5's terminal output).
"""

import builtins;

import json;

import re;

import subprocess;

import sys;

import unittest;

import from pathlib { Path }

glob _HAVE_YAML: any;

glob yaml: any;

glob REPO: any;

glob COMMAND: any;

glob SCRAPER_SKILL: any;

glob EVALUATION: any;

with entry {
    try {
        import yaml;
        _HAVE_YAML = True;
    } except ImportError {
        _HAVE_YAML = False;
    }

    REPO = Path(__file__).resolve().parent.parent;
    COMMAND = REPO / ".claude" / "commands" / "rank.md";
    SCRAPER_SKILL = REPO / ".claude" / "skills" / "job-scraper" / "SKILL.md";
    EVALUATION = REPO / ".claude" / "skills" / "job-application-assistant" / "04-job-evaluation.md";
}

"""Split a command spec into {heading: body} by '##' headers.

    Splitting this way lets a fork's extra sections (e.g. this fork's
    '## Blocker logging') sit between the ones under test without shifting
    which text a given assertion sees.
    """
def _sections(text: builtins.str) -> builtins.dict[builtins.str, builtins.str];

class RankCommandSpec(unittest.TestCase) {
    """Scoring agents read untrusted postings, so they run as the shipped
        least-privilege `posting-scorer` definition (no Edit/Write), gate every
        body with tools/posting_guard.jac, and return the verdict as `guard`."""
    def test_step2_dispatches_posting_scorer_and_returns_guard -> any;

    def test_step2_hands_the_scorer_the_key_it_must_return -> any;

    """No new jobs must not bypass expiry maintenance of ranked jobs."""
    def test_step1_empty_candidates_still_sweeps_and_reports -> any;

    """#534: `rank_state.jac` owns the set of statuses a scoring agent may
        return (`AGENT_STATUSES`), and Step 2's JSON contract must name exactly
        that set. A status the spec offers but the tool lacks is rejected at
        write-back; one the tool accepts but the spec omits is never produced."""
    def test_agent_status_contract_matches_the_state_helper -> any;

    def test_command_file_exists_with_lint_compliant_header -> any;

    def test_step4_persists_gaps_and_strengths -> any;

    def test_step4_documents_verbatim_no_accumulate_and_untrusted_data_rules -> any;

    def test_important_rules_link_honest_scoring_to_persistence -> any;

    def test_job_scraper_schema_note_mentions_strengths_and_gaps -> any;

    """Pins the base field in the seen_jobs.json structure block and the
        never-infer note. Step 2's detail fetch already extracts the deadline, so
        /scrape writes it at first sight instead of leaving it to /rank (#319).
        """
    def test_job_scraper_schema_carries_deadline -> any;

    """`location` meant two incompatible things in seen_jobs.json: a place
        (scraper search output, driving the commute filter) and a PASS/FAIL/FLAG
        verdict (/rank Step 4), so a ranked entry could overwrite "Aarhus,
        Denmark" with "PASS" and no reader could tell which meaning a stored
        value carried (review finding F27B, 2026-08-19)."""
    def test_verdict_is_written_to_location_verdict_not_bare_location -> any;

    """SKILL.md's "do not drop any of these fields" instruction cannot
        protect fields it does not name - and it omitted exactly the three
        rank.md calls as important to persist as the score itself (review
        finding F27 Part A, 2026-08-19)."""
    def test_job_scraper_schema_note_enumerates_the_veto_fields -> any;

    """04-job-evaluation.md is the authoritative file /rank tells its agents
        to read. Its Language Gate preamble once said the gate result "is not a
        field /scrape or /rank track" - written before the gate was wired into
        both consumers, and never updated. An agent reading that learns the
        opposite of what rank.md itself insists on ("These veto fields are as
        important to persist as the score itself"). The framework text must name
        the tracked fields and must not claim they are untracked."""
    def test_evaluation_framework_acknowledges_language_gate_tracking -> any;

    """Rule 6's expiry sweep mutates status automatically from stored
        deadline values, and portals have shipped non-ISO shapes into
        seen_jobs.json ("ASAP" from jobindex, DD.MM.YYYY from jobbank,
        free text from jobdanmark's detail fallback). /outcome carries a
        defensive date-parse rule for mere display; the command that
        silently changes state needs one at least as much."""
    def test_sweep_parses_stored_deadlines_defensively -> any;

    def test_step2_schema_includes_language_gate_fields -> any;

    def test_step3_documents_language_veto -> any;

    """Regression guard: language_gate/language_note were computed in Step 2 and used
        to decide Step 3's veto, but never written to seen_jobs.json - live-debugged and
        fixed once already (a real /rank run showed language_gate: null on every entry
        despite the run reporting real vetoes). This pins the fix in the spec text the
        same way test_step4_persists_gaps_and_strengths pins the sibling strengths/gaps
        persistence bug, so a future edit can't silently reintroduce either loss.
        """
    def test_step4_persists_language_gate_and_language_note -> any;

    """Sibling of test_step4_persists_language_gate_and_language_note: the deadline was
        computed in Step 2 and acted on in Step 3, but never written to seen_jobs.json, so
        the urgency marker fired exactly once and a later run had to re-fetch the posting to
        recover the date (#319). Pins the persistence in the Step 4 field list.
        """
    def test_step4_persists_deadline -> any;

    """Persisting alone does not re-fire the marker: Step 3 must read the stored
        deadline back so urgency is re-derived on every run without re-reading the
        posting (which is the dead-URL source the field exists to replace).
        """
    def test_step3_reads_stored_deadline_without_fetch -> any;

    """Rule 6: entries this run did not re-score still get their stored deadline checked,
        enforcing the only-open-positions rule beyond the moment of fetching.
        """
    def test_step3_documents_expiry_sweep_over_ranked_entries -> any;

    """The sweep's behaviour on the majority case, and its reversibility.

        Most `seen_jobs.json` entries predate the deadline column and carry no
        `deadline` at all, so "left alone" versus "inferred from first_seen" is
        the difference between a no-op and retiring jobs on a date nobody set.
        And a status change made without a fetch needs a stated way back, or
        `expired` reads as terminal and a wrongly swept job looks unrecoverable.
        """
    def test_step3_sweep_states_its_two_boundary_rules -> any;

    """Rule 6 mutates exactly the entries Step 4 says are skipped.

        Step 4's closing line predates the sweep and says already-`ranked` jobs
        are skipped unless `--all` re-scores them. Rule 6 rewrites some of those
        same entries to `expired` with no `--all` and no re-score, so the two
        sections contradict each other unless the exception is named. An
        implementer following Step 4 literally skips the sweep, which is the
        whole feature.
        """
    def test_step4_sweep_is_named_as_the_exception_to_idempotency -> any;

    """Absence-is-not-a-correction is load-bearing, not politeness.

        A `null` from a fetch that degraded to a listing page would erase a real
        stored date; because rule 6 leaves an entry with no stored deadline
        alone, that erasure also makes the entry permanently unsweepable. The
        two rules interlock, and an unexplained constraint is the kind that gets
        simplified away later.
        """
    def test_step4_null_deadline_rule_states_its_interlock_with_the_sweep -> any;

    """A background status mutation with no reported count is the failure mode
        this whole change set exists to object to."""
    def test_step5_reports_the_sweep_counts -> any;

    """The sweep must write its result, or it reproduces the very bug it fixes.

        Step 4's expiry line is scoped to what the Step 2 agents returned. The sweep
        runs over entries this run did not re-score, so without its own persistence
        line the transition happens in reasoning only and disk never changes.
        """
    def test_step4_persists_the_sweeps_expiry -> any;

    def test_step5_documents_language_flag_marker -> any;

    @unittest.skipUnless(
        _HAVE_YAML,
        "PyYAML not installed (the CI Python-test job omits it; the lint job runs lint_skills.jac directly)",
    )
    def test_lint_skills_passes -> any;
}

"""Step 3 must consume the posted_date #391 persists.

    The field exists because a 27-month-old posting ranked Strong Fit at
    position 1 of 133 (#390): the scoring agent noticed the age and wrote it
    into prose nothing reads. Persistence alone changes nothing - these pin
    that /rank actually derives a signal from the stored date, and that the
    signal keeps the schema's own boundary rules (flag never veto, no
    inference for absent values, rule 6's defensive parse).
    """
class PostedDateStalenessSpec(unittest.TestCase) {
    def setUp -> any;

    def test_step3_consumes_posted_date -> any;

    def test_staleness_is_a_flag_never_a_veto -> any;

    def test_staleness_never_inferred_for_absent_values -> any;

    def test_staleness_parses_posted_date_defensively -> any;
}

"""The expensive fetch-and-score batch is bounded independently of output."""
class RankBatchLimitSpec(unittest.TestCase) {
    def setUp -> any;

    def test_step0_documents_default_limit_distinct_from_top -> any;

    def test_step1_applies_limit_via_the_state_tool -> any;

    def test_step5_reports_deferral_and_how_to_continue -> any;
}

"""Guards for routing Step 1/3/4 through tools/rank_state.jac (#395).

    /rank's Step 1 and Step 4 used to read the whole of seen_jobs.json into the
    conversation and write it back by hand - a cost paid on every run
    regardless of batch size, on a file that only grows. These tests pin that
    the spec now delegates that traffic to the CLI instead of re-describing a
    manual read/write, and - the condition attached to this change - that the
    write-back fields the tool must preserve are derived from Step 2's own
    JSON schema rather than retyped as a second, driftable list.
    """
class RankStateToolSpec(unittest.TestCase) {
    def setUp -> any;

    """The field names Step 2's scoring-agent JSON contract declares.

        Extracted from the fenced ```json block in Step 2 rather than
        hardcoded, so a future edit to that contract is what this test reads
        - it cannot silently drift from what agents actually return.
        """
    def _step2_result_fields -> builtins.list[builtins.str];

    def test_step1_never_reads_the_state_file_manually -> any;

    def test_step4_writes_back_through_apply_not_by_hand -> any;

    """The condition on this change: Step 4's write-back semantics must
        survive the move into a script, for every field Step 2 promises to
        return - not just the ones a hand-picked list happens to name."""
    def test_step4_preserves_every_field_step2_declares -> any;

    def test_step4_documents_the_location_verdict_legacy_migration -> any;

    def test_step4_documents_deadline_null_is_not_a_correction -> any;

    def test_step3_sweep_runs_through_the_tool -> any;

    def test_tracker_stays_read_only -> any;

    def test_settings_and_guards_allow_the_new_tool -> any;
}

with entry:__main__ {
    unittest.main();
}

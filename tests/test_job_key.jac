import builtins;

import json;

import subprocess;

import sys;

import unittest;

import from pathlib { Path }

glob REPO: any;

glob TOOL: any;

with entry {
    REPO = Path(__file__).resolve().parent.parent;
    TOOL = tool("job_key");
}

class Slugify(unittest.TestCase) {
    def test_basic -> any;

    def test_strips_punctuation_that_breaks_paths -> any;

    def test_non_latin_script_reduces_to_empty -> any;
}

class MakeKey(unittest.TestCase) {
    def test_shape -> any;

    def test_deterministic_across_calls -> any;

    def test_long_titles_never_collide_after_truncation -> any;

    def test_non_latin_title_falls_back_to_the_portal_job_id -> any;

    def test_non_latin_title_with_no_url_id_still_produces_a_canonical_key -> any;

    def test_non_latin_company_falls_back_without_producing_a_bare_prefix -> any;

    def test_one_url_keeps_one_key_when_a_non_latin_title_is_re_listed -> any;

    def test_distinct_urls_still_get_distinct_keys -> any;
}

class MixedScriptNamesKeepTheirIdentity(unittest.TestCase) {
    def test_titles_sharing_a_digit_fragment_get_distinct_keys -> any;

    def test_titles_sharing_a_latin_word_get_distinct_keys -> any;

    def test_lossy_title_prefers_the_portal_numeric_id -> any;

    def test_companies_sharing_a_latin_word_get_distinct_keys -> any;

    def test_lossy_company_is_stable_across_case_and_urls -> any;

    def test_empty_title_with_a_non_numeric_url_keeps_its_pre_fragment_key -> any;

    def test_latin_names_with_accents_and_ligatures_are_not_lossy -> any;

    def test_latin_letters_without_a_decomposition_are_folded -> any;

    def test_ao_and_ro_no_longer_collide -> any;

    def test_unchanged_letters_keep_their_keys -> any;

    def test_every_table_character_folds_including_capitals -> any;

    def test_latin_extended_a_letters_fold_including_capitals -> any;

    def test_turkish_dotless_i_keeps_its_letters -> any;

    def test_fold_applies_to_decomposed_input_too -> any;

    def test_letter_that_decomposes_into_a_table_letter_is_folded -> any;
}

class CompanyFallbackCLI(unittest.TestCase) {
    def key_for(company, url="https://example.com/jobs/123456") -> any;

    def test_distinct_non_latin_companies_have_distinct_keys -> any;

    def test_company_fallback_is_stable_across_case_normalization_and_urls -> any;

    def test_missing_company_and_existing_ascii_keys_are_unchanged -> any;
}

class CanonicalAndLegacyShape(unittest.TestCase) {
    def test_canonical_accepts_company_underscore_title -> any;

    def test_canonical_rejects_path_breaking_characters -> any;

    def test_legacy_three_part_shape_is_flagged_separately_from_malformed -> any;
}

class AuditCLI(unittest.TestCase) {
    def run_audit(seen: builtins.dict) -> builtins.tuple[builtins.dict, builtins.int];

    def test_clean_state_exits_zero -> any;

    def test_malformed_key_exits_nonzero -> any;

    def test_duplicate_url_exits_nonzero -> any;

    def test_legacy_shape_alone_does_not_fail_the_audit -> any;

    def run_audit_raw(document) -> subprocess.CompletedProcess;

    def test_non_object_state_file_is_reported_not_a_traceback -> any;

    def test_non_object_entry_is_reported_not_a_traceback -> any;

    def test_non_string_url_is_reported_not_a_traceback -> any;
}

class MigrateCLI(unittest.TestCase) {
    static has OLD: any = "mrsk_sfarende";

    static has NEW: any = "maersk_sofarende";

    def setUp -> any;

    def write(seen) -> any;

    def migrate -> any;

    def seen -> any;

    def backups -> any;

    def test_rewrites_the_key_and_keeps_the_entry -> any;

    def test_backup_holds_the_original_bytes -> any;

    def test_existing_new_key_is_reported_not_overwritten -> any;

    def test_chain_moves_in_one_run_and_the_second_run_is_byte_identical -> any;

    def test_migrating_one_key_changes_only_the_lines_that_carry_it -> any;

    def test_second_run_changes_nothing -> any;

    def test_no_drift_writes_no_backup -> any;

    def test_audit_alone_never_rewrites -> any;

    def test_migrate_without_audit_is_a_usage_error -> any;
}

with entry:__main__ {
    unittest.main();
}

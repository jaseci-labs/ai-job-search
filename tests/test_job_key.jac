import json;
import subprocess;
import tempfile;
import unittest;
import from pathlib { Path }

glob TOOL: list[str] = tool("job_key"),
     OLD: str = "mrsk_sfarende",
     NEW: str = "maersk_sofarende",
     MAERSK: dict[str, str] = {"company": "Mærsk", "title": "Søfarende"},
     LINKEDIN: str = "https://kr.linkedin.com/jobs/view/x-4461771225",
     FREEHIRE: str = "https://freehire.me/jobs/";

class Slugify(unittest.TestCase) {
    def test_slugs;
    def test_every_table_character_folds_including_capitals;
}

class MakeKey(unittest.TestCase) {
    def test_exact_keys;
    def test_distinct_postings_get_distinct_canonical_keys;
    def test_one_posting_keeps_one_key;
    def test_fallbacks_keep_a_readable_canonical_shape;
}

class CompanyFallbackCLI(unittest.TestCase) {
    def key_for(company: str, url: str = "https://example.com/jobs/123456") -> str;
    def test_distinct_non_latin_companies_have_distinct_keys;
    def test_company_fallback_is_stable_across_case_normalization_and_urls;
    def test_missing_company_and_existing_ascii_keys_are_unchanged;
}

class CanonicalAndLegacyShape(unittest.TestCase) {
    def test_shapes;
}

class StateFile(unittest.TestCase) {
    def setUp;
    def write(seen: any) -> bytes;
    def audit(*flags: str) -> subprocess.CompletedProcess;
    def migrate -> dict[str, any];
    def seen -> dict[str, any];
    def backups -> list[Path];
}

class AuditCLI(StateFile) {
    def test_exit_code_and_report;
    def test_unusable_state_is_reported_not_a_traceback;
}

class MigrateCLI(StateFile) {
    def test_rewrites_the_key_and_keeps_the_entry;
    def test_backup_holds_the_original_bytes;
    def test_existing_new_key_is_reported_not_overwritten;
    def test_chain_moves_in_one_run_and_the_second_run_is_byte_identical;
    def test_migrating_one_key_changes_only_the_lines_that_carry_it;
    def test_second_run_changes_nothing;
    def test_no_drift_writes_no_backup;
    def test_audit_alone_never_rewrites;
    def test_migrate_without_audit_is_a_usage_error;
}

import io;
import subprocess;
import unittest;
import from contextlib { redirect_stdout }
import from pathlib { Path }
import from unittest.mock { patch }

glob A4: float = 842.0,
     CV: Path = Path("cv/main_example.pdf"),
     ORPHAN: str = "orphaned from its bullets",
     GARDEN: Line = at(50, 59.5, "Plant Grower Example Garden 1981-1990"),
     EXPERIENCE: Line = at(50, 59.5, "Professional Experience"),
     RUNNING_HEADER: Line = at(27, 459.8, "[First] [Last] – CV"),
     DASH: Line = at(62.4, 71.5, "-", bottom=79.5),
     ACHIEVEMENT: Line = at(64.4, 81.3, "[Achievement or responsibility 1]");

def line(top: float, left: float = 50.0, height: float = 10.0, text: str = "x") -> Line;
def at(
    top: float, left: float, text: str, text_left: float | None = None, bottom: float | None = None
) -> Line;

"""Put fake pdftotext binaries on a fake PATH; returns the commands run."""
def fake_path(
    fixture: unittest.TestCase,
    binaries: dict[str, str],
    with_bbox: tuple[str, ...] = (),
    help_on: str = "stderr",
    failure: Exception | None = None,
) -> list[list[str]];

class PageGeometry(unittest.TestCase) {
    def test_gap_and_bottom_space;
    def test_footer_band;
    def test_heading_and_indent_detection;
    def test_text_start;
}

class Orphans(unittest.TestCase) {
    def test_breaks_that_are_reported;
    def test_breaks_that_are_clean;
}

class ExtractorFailure(unittest.TestCase) {
    def setUp;
    def test_failing_extractor_raises_a_skippable_error_naming_both_causes;
    def test_first_candidate_lacks_bbox_and_second_has_it;
    def test_no_candidate_has_bbox_keeps_skip_path;
    def test_find_pdftotext_deduplicates_path_candidates;
    def test_find_pdftotext_caches_resolution;
    def test_missing_poppler_raises_a_skippable_error;
    def test_extractor_failure_exits_2_not_1;
}

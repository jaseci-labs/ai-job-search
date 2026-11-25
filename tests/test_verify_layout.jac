"""Offline tests for tools/verify_layout.jac.

Every case is built from synthetic Page/Line geometry rather than a compiled
PDF, so the suite needs neither Poppler nor a LaTeX toolchain - matching the
repo's CI policy of keeping the Python tool tests self-contained.

The cases marked SILENT FAILURE are the ones that motivated the tool: each
describes a document that compiles cleanly, reports the expected page count,
and passes tools/verify_pdf.jac, while the rendered page is visibly broken.
"""

import builtins;

import io;

import subprocess;

import unittest;

import from contextlib { redirect_stdout }

import from pathlib { Path }

import from unittest.mock { patch }

glob A4_HEIGHT: any = 842.0;

def line(
    top: builtins.float,
    left: builtins.float = 50.0,
    height: builtins.float = 10.0,
    text: builtins.str = "x",
) -> Line;

class TestGapAndBottomSpace(unittest.TestCase) {
    def setUp -> any;

    """SILENT FAILURE: the hole an ejected \\cventry leaves behind."""
    def test_largest_gap_reports_size_and_position -> any;

    """Measured to the last body line (y410), not to the page number at y770."""
    def test_bottom_space_ignores_the_footer_band -> any;

    def test_page_with_no_body_lines_is_empty -> any;

    def test_report_flags_the_hole -> any;
}

class TestFooterBand(unittest.TestCase) {
    def test_single_line_in_band_is_just_the_page_number -> any;

    """SILENT FAILURE: \\enlargethispage pushing body text over the footer."""
    def test_two_lines_in_band_means_body_text_spilled_in -> any;
}

class TestHeadingAndIndentDetection(unittest.TestCase) {
    def setUp -> any;

    def test_taller_line_is_a_heading -> any;

    def test_left_edge_separates_bullets_from_headers -> any;
}

class TestOrphans(unittest.TestCase) {
    """SILENT FAILURE: a heading stranded at the bottom, content overleaf."""
    def test_page_ending_on_a_section_heading -> any;

    """SILENT FAILURE: the \\cventry title on one page, its bullets on the next."""
    def test_entry_header_orphaned_from_its_bullets -> any;

    """moderncv gives the itemize marker its own bbox line: different defect, different fix."""
    def test_lone_list_marker_is_a_split_bullet_not_an_orphaned_header -> any;

    def test_clean_break_reports_nothing -> any;

    """A page that OPENS with bullets must not mistake their indent for its margin."""
    def test_indent_is_judged_against_the_document_margin -> any;
}

"""A bbox line; text_left is where its text starts after a merged list marker."""
def at(top, left, text, text_left=None, bottom=None) -> any;

"""The orphan rule compares where the TEXT starts, not where the line starts.

    Geometry from the #481 repro: entry headers at x59.5; a bullet's marker merged into
    its first line at x58.9, its text at x71.6-72.1, continuations at x72.1. From the
    stock CV: header text at x70.4, an inner bullet's marker in its own line at x71.5
    with the text at x81.3, and an outer marker at x59.0 that extracts either as a line
    of its own or merged into the header line, depending on the font setup.
    """
class TestOrphansReadTextX(unittest.TestCase) {
    def test_bullet_wrapping_across_the_break_is_not_an_orphaned_header -> any;

    def test_bullet_whose_text_opens_with_a_symbol_is_still_a_wrapped_bullet -> any;

    """Dashes are not markers: an em dash can open a bullet's second line."""
    def test_continuation_opening_with_a_dash_is_still_a_wrapped_bullet -> any;

    """The bullet line starts at x58.9, left of the header; its text is further in."""
    def test_header_level_with_merged_bullets_is_an_orphan -> any;

    """The header's text at x70.4 counts as indented, so the left-edge rule missed it."""
    def test_stock_header_whose_outer_marker_is_its_own_line -> any;

    """`○` is not a LIST_MARKERS glyph, so the header keeps x59.0, as the left-edge rule read it."""
    def test_stock_header_with_its_outer_marker_merged_in -> any;

    """Both texts at x70.4, but the merged `○` keeps the header at x59.0."""
    def test_stock_degree_and_description_stay_reported_with_the_marker_merged -> any;

    """Stock CV: the outer marker sits 1.3pt below its one-line item and sorts last.

        The left-edge rule read it as a lone marker whose item was split, although the
        whole item is on p1 and p2 opens with the next item.
        """
    def test_outer_marker_set_below_a_whole_item_is_not_a_split_bullet -> any;

    """A behaviour change, not a fix: master called this a split bullet, and it is split.

        The item's first line is on p1 with its marker 1.3pt below it, and its second line
        opens p2 at the item's text x - the #481 wrapped bullet, which is expected clean.
        """
    def test_two_line_item_wrapping_across_the_break_is_read_like_a_wrapped_bullet -> any;

    """pdftotext's rounded-yMin buckets split a printed line when a bold word sits 0.2pt off."""
    def test_a_printed_line_split_by_font_is_read_as_one -> any;

    def test_stock_bullet_wrapping_across_the_break -> any;

    """A right-aligned header at x459.8 is not text 'set further in' than a bullet."""
    def test_a_running_header_on_the_next_page_is_not_where_the_body_resumes -> any;

    def test_an_orphan_behind_a_running_header_is_still_found -> any;
}

"""parse_pdf's text_left, from (xMin, yMin, yMax, text) words sorted left to right."""
class TestTextStart(unittest.TestCase) {
    def test_a_leading_list_marker_is_set_aside -> any;

    def test_no_marker_means_no_separate_text_start -> any;

    def test_ascii_dashes_and_other_glyphs_are_text -> any;

    def test_a_bare_marker_has_no_text -> any;
}

"""A broken extractor must not masquerade as a broken document.

    Git for Windows ships an xpdf-based pdftotext with no -bbox flag; it shadows
    Poppler in a default PATH and exits 99. Reported as a layout problem it would
    send /apply chasing a phantom hole, so it has to land on the skip path.
    """
class TestExtractorFailure(unittest.TestCase) {
    def setUp -> any;

    def tearDown -> any;

    def test_pdftotext_without_bbox_raises_a_skippable_error -> any;

    """When the first pdftotext candidate lacks -bbox (e.g. Git for Windows's xpdf)
        and a subsequent candidate has it (e.g. Poppler), the tool walks PATH, probes
        with -h, and runs the working candidate with its full path (#655).
        """
    def test_first_candidate_lacks_bbox_and_second_has_it -> any;

    """When no candidate on PATH supports -bbox, the check skips with today's message (#655)."""
    def test_no_candidate_has_bbox_keeps_skip_path -> any;

    """Duplicate entries or multiple PATH directories resolving to the same binary
        are probed only once (#655).
        """
    def test_find_pdftotext_deduplicates_path_candidates -> any;

    """Resolved binary is cached at module level so repeated parse_pdf calls
        avoid re-probing PATH candidates with subprocesses (#655).
        """
    def test_find_pdftotext_caches_resolution -> any;

    """Poppler 26.0x before 26.05 aborts -bbox on an empty Info-dict string, e.g.
        the empty /Title hyperref writes when pdftitle is unset (#451). That crash is
        not the xpdf-shadowing case - it has no -bbox flag and exits 99 - so the
        message must name both, not just the one the exit code happens to match.
        """
    def test_poppler_abort_on_empty_info_string_names_that_cause_too -> any;

    def test_missing_poppler_raises_a_skippable_error -> any;

    """Exit 1 means "your document is broken"; a dead extractor must never claim that."""
    def test_extractor_failure_exits_2_not_1 -> any;
}

with entry:__main__ {
    unittest.main();
}

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

    def test_largest_gap_reports_size_and_position -> any;

    def test_bottom_space_ignores_the_footer_band -> any;

    def test_page_with_no_body_lines_is_empty -> any;

    def test_report_flags_the_hole -> any;
}

class TestFooterBand(unittest.TestCase) {
    def test_single_line_in_band_is_just_the_page_number -> any;

    def test_two_lines_in_band_means_body_text_spilled_in -> any;
}

class TestHeadingAndIndentDetection(unittest.TestCase) {
    def setUp -> any;

    def test_taller_line_is_a_heading -> any;

    def test_left_edge_separates_bullets_from_headers -> any;
}

class TestOrphans(unittest.TestCase) {
    def test_page_ending_on_a_section_heading -> any;

    def test_entry_header_orphaned_from_its_bullets -> any;

    def test_lone_list_marker_is_a_split_bullet_not_an_orphaned_header -> any;

    def test_clean_break_reports_nothing -> any;

    def test_indent_is_judged_against_the_document_margin -> any;
}

def at(top, left, text, text_left=None, bottom=None) -> any;

class TestOrphansReadTextX(unittest.TestCase) {
    def test_bullet_wrapping_across_the_break_is_not_an_orphaned_header -> any;

    def test_bullet_whose_text_opens_with_a_symbol_is_still_a_wrapped_bullet -> any;

    def test_continuation_opening_with_a_dash_is_still_a_wrapped_bullet -> any;

    def test_header_level_with_merged_bullets_is_an_orphan -> any;

    def test_stock_header_whose_outer_marker_is_its_own_line -> any;

    def test_stock_header_with_its_outer_marker_merged_in -> any;

    def test_stock_degree_and_description_stay_reported_with_the_marker_merged -> any;

    def test_outer_marker_set_below_a_whole_item_is_not_a_split_bullet -> any;

    def test_two_line_item_wrapping_across_the_break_is_read_like_a_wrapped_bullet -> any;

    def test_a_printed_line_split_by_font_is_read_as_one -> any;

    def test_stock_bullet_wrapping_across_the_break -> any;

    def test_a_running_header_on_the_next_page_is_not_where_the_body_resumes -> any;

    def test_an_orphan_behind_a_running_header_is_still_found -> any;
}

class TestTextStart(unittest.TestCase) {
    def test_a_leading_list_marker_is_set_aside -> any;

    def test_no_marker_means_no_separate_text_start -> any;

    def test_ascii_dashes_and_other_glyphs_are_text -> any;

    def test_a_bare_marker_has_no_text -> any;
}

class TestExtractorFailure(unittest.TestCase) {
    def setUp -> any;

    def tearDown -> any;

    def test_pdftotext_without_bbox_raises_a_skippable_error -> any;

    def test_first_candidate_lacks_bbox_and_second_has_it -> any;

    def test_no_candidate_has_bbox_keeps_skip_path -> any;

    def test_find_pdftotext_deduplicates_path_candidates -> any;

    def test_find_pdftotext_caches_resolution -> any;

    def test_poppler_abort_on_empty_info_string_names_that_cause_too -> any;

    def test_missing_poppler_raises_a_skippable_error -> any;

    def test_extractor_failure_exits_2_not_1 -> any;
}

with entry:__main__ {
    unittest.main();
}

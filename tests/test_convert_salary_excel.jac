import io;
import unittest;
import from contextlib { redirect_stderr }
import from types { SimpleNamespace }

class FakeWorksheet {
    has rows: list[any],
        title: str = "Sheet1";

    def iter_rows(
        min_row: int = 1, max_row: int | None = None, values_only: bool = False
    ) -> list[any];
    def __getitem__(row_number: int) -> list[any];
}

def parsed(*rows: any) -> list[tuple[str, str, any]];

def both(count: any, index: any) -> dict[str, any];

class ConverterUnits(unittest.TestCase) {
    def test_header_classification;
    def test_parse_numeric_cell_locales;
    def test_parse_sheet_finds_columns_and_pairs_categories;
    def test_parse_sheet_warns_when_no_salary_columns_detected;
    def test_lookup_renders_a_bare_pair_as_one_row;
}

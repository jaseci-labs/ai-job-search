import unittest;

glob CAFE: str = "<p>Café</p>";

def page(body: str, head: str = "") -> str;

class PageDecode(unittest.TestCase) {
    def test_declared_legacy_charsets_are_honoured;
    def test_valid_utf8_is_unchanged_whatever_the_page_declares;
    def test_undeclared_or_refused_labels_keep_utf8_with_replacement;
}

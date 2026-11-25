impl page(body: builtins.str, head: builtins.str = "") -> builtins.str {
    return f"<!doctype html><html><head>{head}<title>Posting</title></head><body>{body}</body></html>";
}

impl LegacyCharsets.test_http_equiv_euc_kr_is_read_as_cp949 -> any {
    text: any = page(
        "<h1>백엔드 개발자 채용</h1><p>똠방각하 우대</p>",
        "<meta http-equiv=\"Content-Type\" content=\"text/html; charset=euc-kr\">",
    );
    decoded: any = decode_page(text.encode("cp949"));
    self.assertIn("백엔드 개발자 채용", decoded);
    self.assertIn("똠방각하", decoded);
    self.assertNotIn("�", decoded);
}

impl LegacyCharsets.test_meta_charset_shift_jis -> any {
    text: any = page("<h1>データエンジニア募集</h1>", "<meta charset=\"Shift_JIS\">");
    self.assertIn("データエンジニア募集", decode_page(text.encode("cp932")));
}

impl LegacyCharsets.test_iso_8859_1_label_is_read_as_windows_1252 -> any {
    text: any = page("<p>Løn: 50.000 € om måneden</p>", "<meta charset=iso-8859-1>");
    self.assertIn("Løn: 50.000 € om måneden", decode_page(text.encode("cp1252")));
}

impl LegacyCharsets.test_windows_1251_cyrillic -> any {
    text: any = page("<p>Инженер данных</p>", "<meta charset=\"windows-1251\">");
    self.assertIn("Инженер данных", decode_page(text.encode("cp1251")));
}

impl LegacyCharsets.test_utf16_byte_order_mark -> any {
    text: any = page("<p>Ingeniør</p>");
    self.assertIn("Ingeniør", decode_page(text.encode("utf-16")));
}

impl UnchangedBehaviour.test_valid_utf8_is_unchanged -> any {
    raw: any = page("<p>Ingeniør søges, 백엔드, データ</p>").encode("utf-8");
    self.assertEqual(decode_page(raw), raw.decode("utf-8", errors="replace"));
}

impl UnchangedBehaviour.test_valid_utf8_wins_over_a_wrong_meta_label -> any {
    raw: any = page("<p>Café</p>", "<meta charset=\"iso-8859-1\">").encode("utf-8");
    self.assertIn("Café", decode_page(raw));
}

impl UnchangedBehaviour.test_utf8_bom_is_kept_for_the_invisible_character_count -> any {
    raw: any = b"\xef\xbb\xbf" + page("<p>Plain posting.</p>").encode("utf-8");
    self.assertTrue(decode_page(raw).startswith("﻿"));
}

impl UnchangedBehaviour.test_undeclared_legacy_bytes_fall_back_to_utf8_with_replacement -> any {
    raw: any = page("<p>Café</p>").encode("latin-1");
    self.assertEqual(decode_page(raw), raw.decode("utf-8", errors="replace"));
}

impl UnchangedBehaviour.test_unknown_and_unsafe_labels_are_ignored -> any {
    for label in ("x-unknown", "utf-7", "utf-16") {
        raw: any = page("<p>Café</p>", f"<meta charset=\"{label}\">").encode("latin-1");
        with self.subTest(label=label) {
            self.assertIsNone(declared_codec(raw));
            self.assertEqual(decode_page(raw), raw.decode("utf-8", errors="replace"));
        }
    }
}

impl UnchangedBehaviour.test_meta_after_the_prescan_window_is_ignored -> any {
    raw: any = (" " * 1100 + page("<p>Café</p>", "<meta charset=\"windows-1252\">")).encode(
        "cp1252"
    );
    self.assertIsNone(declared_codec(raw));
}

impl page(body: str, head: str = "") -> str {
    return f"<!doctype html><html><head>{head}<title>Posting</title></head><body>{body}</body></html>";
}

impl PageDecode.test_declared_legacy_charsets_are_honoured {
    cases: list[tuple[str, str, str]] = [
        (
            "백엔드 개발자 채용, 똠방각하 우대",
            "<meta http-equiv=\"Content-Type\" content=\"text/html; charset=euc-kr\">",
            "cp949",
        ),
        ("データエンジニア募集", "<meta charset=\"Shift_JIS\">", "cp932"),
        ("Løn: 50.000 € om måneden", "<meta charset=iso-8859-1>", "cp1252"),
        ("Инженер данных", "<meta charset=\"windows-1251\">", "cp1251"),
        ("Ingeniør", "", "utf-16"),
    ];
    for (text, head, codec) in cases {
        with self.subTest(codec=codec) {
            decoded: str = decode_page(page(text, head).encode(codec));
            self.assertIn(text, decoded);
            self.assertNotIn("�", decoded);
        }
    }
}

impl PageDecode.test_valid_utf8_is_unchanged_whatever_the_page_declares {
    for head in ("", "<meta charset=\"iso-8859-1\">") {
        raw: bytes = page("<p>Café søges, 백엔드, データ</p>", head).encode("utf-8");
        self.assertEqual(decode_page(raw), raw.decode("utf-8"));
    }
    bom: bytes = b"\xef\xbb\xbf" + page("<p>Plain posting.</p>").encode("utf-8");
    self.assertTrue(decode_page(bom).startswith("﻿"));
}

impl PageDecode.test_undeclared_or_refused_labels_keep_utf8_with_replacement {
    refused: list[bytes] = [
        page(CAFE, f"<meta charset=\"{label}\">").encode("latin-1")
        for label in ("x-unknown", "utf-7", "utf-16")
    ];
    beyond_prescan: bytes = (" " * 1100 + page(CAFE, "<meta charset=\"windows-1252\">")).encode(
        "cp1252"
    );
    for raw in [page(CAFE).encode("latin-1"), beyond_prescan, *refused] {
        with self.subTest(raw=raw[:60]) {
            self.assertIsNone(declared_codec(raw));
            self.assertEqual(decode_page(raw), raw.decode("utf-8", errors="replace"));
        }
    }
}

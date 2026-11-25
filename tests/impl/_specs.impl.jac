impl doc(rel: str) -> str {
    return (REPO / rel).read_text(encoding="utf-8");
}

impl section(text: str, start: str, stop: str = "^#{1,4} ") -> str {
    rest: str = text[text.index(start) + len(start):];
    end: re.Match | None = re.search(stop, rest, re.MULTILINE);
    return rest[:end.start()] if end else rest;
}

impl h2(text: str, title: str) -> str {
    return section(text, f"\n## {title}\n", "^## ");
}

impl between(text: str, start: str, stop: str) -> str {
    rest: str = text[text.index(start) + len(start):];
    return rest[:rest.index(stop)];
}

impl expect(t: unittest.TestCase, text: str, *phrases: str) -> None {
    for phrase in phrases {
        with t.subTest(phrase=phrase) {
            t.assertIn(phrase, text);
        }
    }
}

impl expect_not(t: unittest.TestCase, text: str, *phrases: str) -> None {
    for phrase in phrases {
        with t.subTest(absent=phrase) {
            t.assertNotIn(phrase, text);
        }
    }
}

impl expect_re(t: unittest.TestCase, text: str, *patterns: str) -> None {
    for pattern in patterns {
        with t.subTest(pattern=pattern) {
            t.assertRegex(text, pattern);
        }
    }
}

impl expect_all(t: unittest.TestCase, cases: list[tuple[str, str | None, list[str]]]) -> None {
    for (rel, heading, phrases) in cases {
        text: str = doc(rel) if heading is None else section(doc(rel), heading);
        with t.subTest(file=rel, heading=heading) {
            expect(t, text, *phrases);
        }
    }
}

impl lint_skills_passes(t: unittest.TestCase) -> None {
    if importlib.util.find_spec("yaml") is None {
        t.skipTest("PyYAML not installed");
    }
    result: subprocess.CompletedProcess = subprocess.run(
        tool("lint_skills"), cwd=REPO, capture_output=True, text=True
    );
    t.assertEqual(result.returncode, 0, result.stdout + result.stderr);
}

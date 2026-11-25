impl doc(rel: str) -> str {
    return (REPO / rel).read_text(encoding="utf-8");
}

impl command(name: str) -> str {
    return doc(f".claude/commands/{name}.md");
}

impl skill(name: str) -> str {
    return doc(f".claude/skills/job-application-assistant/{name}");
}

impl between(text: str, start: str, end: str) -> str {
    begin: int = text.index(start);
    return text[begin:text.index(end, begin)];
}

impl under(text: str, heading: str) -> str {
    rest: str = text[text.index(heading) + len(heading):];
    end = re.search("^#{1,4} ", rest, re.MULTILINE);
    return rest[:end.start()] if end else rest;
}

impl parts(text: str, level: str) -> dict[str, str] {
    found: dict[str, str] = {};
    for part in text.split(f"\n{level} ")[1:] {
        (heading, _, body) = part.partition("\n");
        found[heading.strip()] = body;
    }
    return found;
}

impl h2(text: str) -> list[str] {
    return [line[3:].strip() for line in text.splitlines() if line.startswith("## ")];
}

impl quoted(text: str) -> list[str] {
    return re.findall("\"([^\"]+)\"", text);
}

impl bash_block(text: str, after: str) -> str {
    return re.search("```bash\\n(.*?)```", text.split(after, 1)[1], re.DOTALL).group(1);
}

impl check(
    fixture: unittest.TestCase, text: str, present: list[str], absent: list[str] = []
) -> None {
    for phrase in present {
        with fixture.subTest(present=phrase) {
            fixture.assertIn(phrase, text);
        }
    }
    for phrase in absent {
        with fixture.subTest(absent=phrase) {
            fixture.assertNotIn(phrase, text);
        }
    }
}

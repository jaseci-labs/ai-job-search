impl _inside_repo(path: Path) -> bool {
    probe: Path = path.expanduser();
    if not probe.is_absolute() {
        probe = Path.cwd() / probe;
    }
    while not probe.exists() {
        if probe.parent == probe {
            return False;
        }
        probe = probe.parent;
    }
    for ancestor in (probe, *probe.parents) {
        try {
            if os.path.samefile(ancestor, ROOT) {
                return True;
            }
        } except OSError {
            return False;
        }
    }
    return False;
}

impl _fold(text: str) -> str {
    text = text.replace("\r\n", "\n").replace("\r", "\n");
    text = re.sub("[ \\t\\xa0\\f\\v]+", " ", text);
    text = re.sub(" *\\n *", "\n", text);
    return re.sub("\\n{3,}", "\n\n", text).strip();
}

impl _tag_text(run: str) -> str {
    return "".join([chr(ord(c) - TAG_BASE) for c in run if 32 <= ord(c) - TAG_BASE < 127]);
}

impl _selector_text(run: str) -> str {
    data: bytes = bytes([
        ord(c) - 0xFE00 if ord(c) <= 0xFE0F else ord(c) - 0xE0100 + 16
        for c in run
    ]);
    return "".join([c for c in data.decode("utf-8", errors="replace") if c.isprintable()]);
}

impl clean_text(text: str) -> tuple[str, dict[str, any]] {
    has_flag: bool = RGI_TAG_FLAG.search(text) is not None;
    tag_runs: list[str] = TAG_RUN.findall(RGI_TAG_FLAG.sub("", text));
    selector_runs: list[str] = VARIATION_RUN.findall(text);
    sizes: dict[str, int] = {
        key: sum([text.count(c) for c in chars])
        for (key, chars) in COUNTED.items()
    };
    sizes["tag"] = sum([len(run) for run in tag_runs]);
    sizes["variation"] = len(VARIATION.findall(text));
    flagged: int = 0;
    for (i, ch) in enumerate(text) {
        splits_word: bool = (ch in ZERO_WIDTH or ch == BOM)
            and text[max(i - 1, 0):i].isalpha()
            and text[i + 1:i + 2].isalpha();
        if ch in BIDI_TAMPER or splits_word {
            flagged += 1;
        }
    }
    spelled: list[str] = [_tag_text(run).strip() for run in tag_runs] + [
        _selector_text(run).strip()
        for run in selector_runs
    ];
    strip: dict[int, any] = str.maketrans("", "", INVISIBLE);
    text = VARIATION.sub("", text);
    if has_flag {
        kept: list[str] = RGI_TAG_FLAG.findall(text) + [""];
        text = "".join([
            part.translate(strip) + flag
            for (part, flag) in zip(RGI_TAG_FLAG.split(text), kept)
        ]);
    } else {
        text = text.translate(strip);
    }
    return (
        _fold(text),
        {
            "invisible_chars": {key: n for (key, n) in sizes.items() if n},
            "invisible_flagged": flagged,
            "invisible_text": [s[:LINE_MAX] for s in spelled if s],
        },
    );
}

impl _attrs(raw: str) -> dict[str, str] {
    return {
        m.group(1).lower(): "" if m.lastindex == 1 else m.group(m.lastindex)
        for m in ATTR.finditer(raw)
    };
}

impl _is_hidden(raw_attrs: str) -> bool {
    attrs: dict[str, str] = _attrs(raw_attrs);
    if "hidden" in attrs or attrs.get("aria-hidden", "").strip().lower() == "true" {
        return True;
    }
    style: str = CSS_COMMENT.sub("", html.unescape(attrs.get("style", "")));
    return bool(
        HIDDEN_STYLE.search(style) or (COLLAPSED_BOX.search(style) and CLIPPED.search(style))
    );
}

impl clean_html(markup: str) -> tuple[str, dict[str, any]] {
    hidden_parts: list[str] = [];
    hidden_blocks: list[str] = [];
    visible: list[str] = [];
    hidden_buf: list[str] = [];
    stack: list[str] = [];
    nav_at: set[int] = set();
    hidden_at: int | None = None;
    pos: int = 0;

    def collect(found: re.Match[str]) -> str {
        inner: str = re.sub("<!--|-->", " ", found.group(0));
        hidden_parts.append(html.unescape(re.sub("<[^>]+>", " ", inner)));
        return " ";
    }

    def emit(text: str) -> None {
        (visible if hidden_at is None else hidden_buf).append(text);
    }

    def flush_hidden -> None {
        block: str = _fold(html.unescape("".join(hidden_buf)));
        hidden_buf.clear();
        hidden_at = None;
        if block {
            hidden_blocks.append(clean_text(block)[0][:EXCERPT]);
            hidden_parts.append(block);
        }
    }

    def pop_to(index: int) -> None {
        del stack[index:];
        nav_at = {i for i in nav_at if i < index};
        if hidden_at is not None and hidden_at >= len(stack) {
            flush_hidden();
        }
    }

    markup = DROP_BLOCKS.sub(collect, COMMENT.sub(collect, PRESTRIP.sub(" ", markup)));
    for m in TAG.finditer(markup) {
        emit(markup[pos:m.start()]);
        pos = m.end();
        name: str = m.group(2).lower();
        raw_attrs: str = m.group(3);
        if name in BLOCK {
            emit("\n");
        }
        if m.group(1) {
            if name in stack {
                pop_to(len(stack) - 1 - stack[::-1].index(name));
            }
            continue;
        }
        is_nav: bool = bool(nav_at)
            or name == "nav"
            or _attrs(raw_attrs).get("role", "").strip().lower() == "navigation";
        hides: bool = _is_hidden(raw_attrs);
        if (hidden_at is not None or hides) and not is_nav {
            hidden_parts.extend(URL.findall(html.unescape(raw_attrs)));
        }
        if name in VOID {
            continue;
        }
        if stack
            and (
                (name in IMPLIED_END and stack[-1] == name)
                or (name in CLOSES_P and stack[-1] == "p")
            )
        {
            pop_to(len(stack) - 1);
        }
        stack.append(name);
        if is_nav {
            nav_at.add(len(stack) - 1);
        }
        if hidden_at is None and hides {
            hidden_at = len(stack) - 1;
        }
    }
    emit(markup[pos:]);
    if hidden_at is not None {
        flush_hidden();
    }
    return (
        _fold(html.unescape("".join(visible))),
        {"hidden_blocks": hidden_blocks, "hidden_text": "\n".join(hidden_parts)},
    );
}

impl _excerpt(line: str, at: int) -> str {
    if len(line) <= LINE_MAX {
        return line;
    }
    end: int = min(len(line), max(0, at - LINE_MAX // 3) + LINE_MAX);
    start: int = max(0, end - LINE_MAX);
    return ("…" if start else "") + line[start:end] + ("…" if end < len(line) else "");
}

impl _instruction_at(line: str) -> int | None {
    for pattern in INSTRUCTION_PATTERNS {
        found: re.Match[str] | None = pattern.search(line);
        if found {
            return found.start();
        }
    }
    return None;
}

impl scan(visible: str, hidden: str) -> dict[str, any] {
    instruction_like: dict[str, str] = {};
    for line in visible.splitlines() + hidden.splitlines() {
        stripped: str = line.strip();
        if stripped and stripped not in instruction_like {
            at: int | None = _instruction_at(stripped);
            if at is not None {
                instruction_like[stripped] = _excerpt(stripped, at);
            }
        }
    }
    mixed: list[str] = [
        word
        for word in WORD.findall(visible + "\n" + hidden)
        if LATIN.search(word) and CONFUSABLE.search(word)
    ];
    return {
        "instruction_like": list(instruction_like.values()),
        "hidden_urls": list(dict.fromkeys(URL.findall(hidden))),
        "visible_url_count": len(URL.findall(visible)),
        "homoglyph_runs": list(dict.fromkeys(mixed)),
    };
}

impl _phrases(counts: list[int], names: list[tuple[str, str]]) -> list[str] {
    return [f"{n} {one if n == 1 else many}" for (n, (one, many)) in zip(counts, names) if n];
}

impl verdict(findings: dict[str, any]) -> str {
    if findings.get("verdict") == NO_TEXT_VERDICT {
        return NO_TEXT_VERDICT;
    }
    alarms: list[str] = _phrases(
        [
            len(findings.get("instruction_like") or []),
            int(findings.get("invisible_flagged") or 0),
            int((findings.get("invisible_chars") or {}).get("tag") or 0),
            len(findings.get("invisible_text") or []),
            len(findings.get("homoglyph_runs") or []),
        ],
        ALARMS,
    );
    removed: str = " and ".join(
        _phrases(
            [len(findings.get("hidden_blocks") or []), len(findings.get("hidden_urls") or [])],
            CONTEXT,
        ),
    );
    if alarms {
        line: str = "posting_guard: ⚠ " + ", ".join(alarms) + " - review before continuing";
        return f"{line} ({removed} removed)" if removed else line;
    }
    if removed {
        return f"posting_guard: clean ({removed} removed, none instruction-like)";
    }
    return "posting_guard: clean";
}

impl guard(raw: str, mode: str) -> tuple[str, dict[str, any]] {
    if mode == "auto" {
        mode = "html" if HTML_HINT.search(raw) else "text";
    }
    text: str = raw;
    hidden: dict[str, any] = {"hidden_blocks": [], "hidden_text": ""};
    if mode == "html" {
        (text, hidden) = clean_html(raw);
    }
    (text, tf) = clean_text(text);
    (hidden_text, hidden_tf) = clean_text(hidden["hidden_text"]);
    for (key, n) in hidden_tf["invisible_chars"].items() {
        tf["invisible_chars"][key] = tf["invisible_chars"].get(key, 0) + n;
    }
    tf["invisible_flagged"] += hidden_tf["invisible_flagged"];
    tf["invisible_text"] += hidden_tf["invisible_text"];
    findings: dict[str, any] = {
        "hidden_blocks": hidden["hidden_blocks"],
        **tf,
        **scan(text, "\n".join([hidden_text, *tf["invisible_text"]])),
    };
    line: str = verdict(findings);
    findings["verdict"] = NO_TEXT_VERDICT if not text and line == "posting_guard: clean" else line;
    return (text, findings);
}

impl _plain_findings(findings: dict[str, any]) -> str {
    lines: list[str] = [];
    for key in LISTED {
        lines.append(f"{key} ({len(findings[key])}):");
        lines.extend([f"  - \"{item}\"" for item in findings[key]]);
    }
    chars: str = ", ".join([f"{k}={v}" for (k, v) in findings["invisible_chars"].items()]);
    return "\n".join([
        *lines,
        f"invisible_chars: {chars or 'none'}",
        f"invisible_flagged: {findings['invisible_flagged']}",
        f"visible_url_count: {findings['visible_url_count']}",
    ]);
}

impl _force_utf8_output -> None {
    for stream in (sys.stdout, sys.stderr) {
        reconfigure: any = getattr(stream, "reconfigure", None);
        if reconfigure {
            reconfigure(encoding="utf-8");
        }
    }
}

impl _read_input(path: Path | None, mode: str) -> str {
    buffer: any = getattr(sys.stdin, "buffer", None);
    if path is None and buffer is None {
        return sys.stdin.read();
    }
    data: bytes = buffer.read() if path is None else path.read_bytes();
    return decode_page(data) if mode == "html" else data.decode("utf-8", errors="replace");
}

impl main(argv: list[str] | None = None) -> int {
    _force_utf8_output();
    parser: argparse.ArgumentParser = argparse.ArgumentParser(
        prog="posting_guard.jac",
        description="Integrity gate for a fetched posting; see module docstring.",
    );
    parser.add_argument(
        "--in", dest="infile", type=Path, default=None, help="input file (default: stdin)"
    );
    mode: any = parser.add_mutually_exclusive_group();
    mode.add_argument("--html", action="store_const", const="html", dest="mode");
    mode.add_argument("--text", action="store_const", const="text", dest="mode");
    parser.add_argument(
        "--out", type=Path, default=None, help="write the cleaned text here instead of stdout"
    );
    parser.add_argument("--json", action="store_true", help="print findings as JSON");
    parser.set_defaults(mode="auto");
    args: argparse.Namespace = parser.parse_args(argv);
    try {
        raw: str = _read_input(args.infile, args.mode);
    } except OSError as exc {
        print(f"posting_guard: cannot read input: {exc}", file=sys.stderr);
        return 2;
    }
    (cleaned, findings) = guard(raw, args.mode);
    refused: bool = findings["verdict"] == NO_TEXT_VERDICT;
    print(findings["verdict"]);
    print("--- findings ---");
    print(
        json.dumps(findings, ensure_ascii=False, indent=2)
            if args.json
            else _plain_findings(findings),
    );
    if args.out is None {
        print("--- text ---");
        print(cleaned);
    } elif _inside_repo(args.out) {
        print(
            f"posting_guard: refusing to write inside the repo ({args.out}); the cleaned posting is untrusted text and belongs in the session scratchpad",
            file=sys.stderr,
        );
        return 2;
    } elif not refused {
        args.out.parent.mkdir(parents=True, exist_ok=True);
        args.out.write_text(cleaned + "\n", encoding="utf-8");
        print(f"saved={args.out}");
    }
    return 1 if refused else 0;
}

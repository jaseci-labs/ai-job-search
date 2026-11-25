impl _inside_repo(path: Path) -> builtins.bool {
    candidate: any = path.expanduser();
    if not candidate.is_absolute() {
        candidate = Path.cwd() / candidate;
    }
    probe: any = candidate;
    while not probe.exists() {
        parent: any = probe.parent;
        if parent == probe {
            return False;
        }
        probe = parent;
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

impl _fold(text: builtins.str) -> builtins.str {
    text = text.replace("\r\n", "\n").replace("\r", "\n");
    text = re.sub("[ \\t\\xa0\\f\\v]+", " ", text);
    text = re.sub(" *\\n *", "\n", text);
    text = re.sub("\\n{3,}", "\n\n", text);
    return text.strip();
}

impl clean_text(text: builtins.str) -> any {
    counts: any = {};
    flagged: any = 0;
    for (key, chars) in (
        ("zero_width", ZERO_WIDTH),
        ("bidi", BIDI),
        ("format", FORMAT),
        ("bom", BOM),
    ) {
        n: any = sum(text.count(c) for c in chars);
        if n {
            counts[key] = n;
        }
    }
    flags: any = RGI_TAG_FLAG.findall(text);
    unflagged: any = RGI_TAG_FLAG.sub("", text);
    tags: any = sum(1 for ch in unflagged if "󠀀" <= ch <= "󠁿");
    if tags {
        counts["tag"] = tags;
    }
    variation: any = len(VARIATION.findall(text));
    if variation {
        counts["variation"] = variation;
    }
    for (i, ch) in enumerate(text) {
        if ch in BIDI_TAMPER {
            flagged += 1;
        } elif ch in ZERO_WIDTH or ch == BOM {
            before: any = text[i - 1] if i else "";
            after: any = text[i + 1] if i + 1 < len(text) else "";
            if before.isalpha() and after.isalpha() {
                flagged += 1;
            }
        }
    }
    invisible_text: any = [];
    run: any;
    for run in TAG_RUN.findall(unflagged) {
        decoded: any = "".join(
            chr(ord(c) - 917504) for c in run if 32 <= ord(c) - 917504 < 127
        ).strip();
        if decoded {
            invisible_text.append(decoded[:LINE_MAX]);
        }
    }
    for run in VARIATION_RUN.findall(text) {
        data: any = `bytes(
            ord(c) - 65024 if ord(c) <= 65039 else ord(c) - 917760 + 16 for c in run
        );
        decoded = "".join(
            c for c in data.decode("utf-8", errors="replace") if c.isprintable()
        ).strip();
        if decoded {
            invisible_text.append(decoded[:LINE_MAX]);
        }
    }
    text = VARIATION.sub("", text);
    if flags {
        strip: any = {ord(c): None for c in INVISIBLE};
        pieces: any;
        last: any;
        (pieces, last) = ([], 0);
        for m in RGI_TAG_FLAG.finditer(text) {
            pieces.append(text[last:m.start()].translate(strip));
            pieces.append(m.group(0));
            last = m.end();
        }
        pieces.append(text[last:].translate(strip));
        text = "".join(pieces);
    } else {
        text = text.translate({ord(c): None for c in INVISIBLE});
    }
    return (
        _fold(text),
        {"invisible_chars": counts, "invisible_flagged": flagged, "invisible_text": invisible_text},
    );
}

impl _attrs(raw: builtins.str) -> builtins.dict {
    out: any = {};
    for m in ATTR.finditer(raw) {
        value: any = m.group(2)
            if m.group(2) is not None
            else m.group(3) if m.group(3) is not None else m.group(4) or "";
        out[m.group(1).lower()] = value;
    }
    return out;
}

impl _style(attrs: builtins.dict) -> builtins.str {
    return CSS_COMMENT.sub("", html.unescape(attrs.get("style", "")));
}

impl _is_hidden(raw_attrs: builtins.str) -> builtins.bool {
    attrs: any = _attrs(raw_attrs);
    if "hidden" in attrs or attrs.get("aria-hidden", "").strip().lower() == "true" {
        return True;
    }
    style: any = _style(attrs);
    if HIDDEN_STYLE.search(style) {
        return True;
    }
    return `bool(COLLAPSED_BOX.search(style) and CLIPPED.search(style));
}

impl clean_html(markup: builtins.str) -> any {
    hidden_parts: any;
    hidden_blocks: any;
    visible: any;
    hidden_buf: any;
    stack: any;
    nav_at: any;
    hidden_at: any;
    hidden_parts = [];
    hidden_blocks = [];

    def collect(`match) -> any {
        inner: any = re.sub("<!--|-->", " ", `match.group(0));
        inner = re.sub("<[^>]+>", " ", inner);
        hidden_parts.append(html.unescape(inner));
        return " ";
    }

    markup = PRESTRIP.sub(" ", markup);
    markup = COMMENT.sub(collect, markup);
    markup = DROP_BLOCKS.sub(collect, markup);

    visible = [];
    hidden_buf = [];
    stack = [];
    nav_at = set[any]();
    hidden_at = None;
    pos: any = 0;

    def emit(text) -> any {
        (visible if hidden_at is None else hidden_buf).append(text);
    }

    def flush_hidden -> any {
        block: any = _fold(html.unescape("".join(hidden_buf)));
        hidden_buf.clear();
        hidden_at = None;
        if block {
            hidden_blocks.append(clean_text(block)[0][:EXCERPT]);
            hidden_parts.append(block);
        }
    }

    def pop_to(index) -> any {
        del stack[index:];
        nav_at = {i for i in nav_at if i < index};
        if hidden_at is not None and hidden_at >= len(stack) {
            flush_hidden();
        }
    }

    def last_index(name) -> any {
        for i in range(len(stack) - 1, -1, -1) {
            if stack[i] == name {
                return i;
            }
        }
        return None;
    }

    for m in TAG.finditer(markup) {
        emit(markup[pos:m.start()]);
        pos = m.end();
        closing: any;
        name: any;
        raw_attrs: any;
        (closing, name, raw_attrs) = (m.group(1), m.group(2).lower(), m.group(3));
        if name in BLOCK {
            emit("\n");
        }
        if closing {
            index: any = last_index(name);
            if index is not None {
                pop_to(index);
            }
            continue;
        }
        is_nav: any = `bool(nav_at)
            or operator.eq(name, "nav")
            or operator.eq(_attrs(raw_attrs).get("role", "").strip().lower(), "navigation");
        is_hidden: any = hidden_at is not None or _is_hidden(raw_attrs);
        if is_hidden and not is_nav {
            for u in URL.findall(html.unescape(raw_attrs)) {
                hidden_parts.append(u);
            }
        }
        if name in VOID {
            continue;
        }
        if name in IMPLIED_END and stack and stack[-1] == name {
            pop_to(len(stack) - 1);
        } elif name in CLOSES_P and stack and stack[-1] == "p" {
            pop_to(len(stack) - 1);
        }
        stack.append(name);
        idx: any = len(stack) - 1;
        if is_nav {
            nav_at.add(idx);
        }
        if hidden_at is None and _is_hidden(raw_attrs) {
            hidden_at = idx;
        }
    }
    emit(markup[pos:]);
    if hidden_at is not None {
        flush_hidden();
    }

    text: any = html.unescape("".join(visible));
    return (_fold(text), {"hidden_blocks": hidden_blocks, "hidden_text": "\n".join(hidden_parts)});
}

impl _excerpt(line: builtins.str, at: builtins.int) -> builtins.str {
    if len(line) <= LINE_MAX {
        return line;
    }
    lead: any = LINE_MAX // 3;
    start: any = max(0, at - lead);
    end: any = min(len(line), start + LINE_MAX);
    start = max(0, end - LINE_MAX);
    head: any = "…" if start else "";
    tail: any = "…" if end < len(line) else "";
    return f"{head}{line[start:end]}{tail}";
}

impl scan(visible: builtins.str, hidden: builtins.str) -> builtins.dict {
    stripped: any;
    seen: any = set[any]();
    instruction_like: any = [];
    for line in visible.splitlines() + hidden.splitlines() {
        stripped = line.strip();
        if not stripped or stripped in seen {
            continue;
        }
        `match: any = next(
            (m for m in (p.search(stripped) for p in INSTRUCTION_PATTERNS) if m), None
        );
        if `match {
            seen.add(stripped);
            instruction_like.append(_excerpt(stripped, `match.start()));
        }
    }
    hidden_urls: any = [];
    for url in URL.findall(hidden) {
        if url not in hidden_urls {
            hidden_urls.append(url);
        }
    }
    homoglyphs: any = [];
    for word in WORD.findall(visible + "\n" + hidden) {
        if LATIN.search(word) and CONFUSABLE.search(word) and word not in homoglyphs {
            homoglyphs.append(word);
        }
    }
    return {
        "instruction_like": instruction_like,
        "hidden_urls": hidden_urls,
        "visible_url_count": len(URL.findall(visible)),
        "homoglyph_runs": homoglyphs,
    };
}

impl _plural(n: builtins.int, one: builtins.str, many: builtins.str) -> builtins.str {
    return f"{n} {one if n == 1 else many}";
}

impl verdict(findings: builtins.dict) -> builtins.str {
    if findings.get("verdict") == NO_TEXT_VERDICT {
        return NO_TEXT_VERDICT;
    }
    alarms: any = [];
    n: any = len(findings.get("instruction_like") or []);
    if n {
        alarms.append(_plural(n, "instruction-like line", "instruction-like lines"));
    }
    n = `int(findings.get("invisible_flagged") or 0);
    if n {
        alarms.append(
            _plural(n, "invisible character inside words", "invisible characters inside words")
        );
    }
    n = `int((findings.get("invisible_chars") or {}).get("tag") or 0);
    if n {
        alarms.append(
            _plural(
                n,
                "tag character (text hidden from the reader)",
                "tag characters (text hidden from the reader)",
            ),
        );
    }
    n = len(findings.get("invisible_text") or []);
    if n {
        alarms.append(
            _plural(
                n,
                "string spelled in invisible characters",
                "strings spelled in invisible characters",
            ),
        );
    }
    n = len(findings.get("homoglyph_runs") or []);
    if n {
        alarms.append(_plural(n, "mixed-script word", "mixed-script words"));
    }

    context: any = [];
    n = len(findings.get("hidden_blocks") or []);
    if n {
        context.append(_plural(n, "hidden block", "hidden blocks"));
    }
    n = len(findings.get("hidden_urls") or []);
    if n {
        context.append(_plural(n, "hidden URL", "hidden URLs"));
    }
    removed: any = " and ".join(context);

    if alarms {
        line: any = "posting_guard: ⚠ " + ", ".join(alarms) + " - review before continuing";
        return f"{line} ({removed} removed)" if removed else line;
    }
    if removed {
        return f"posting_guard: clean ({removed} removed, none instruction-like)";
    }
    return "posting_guard: clean";
}

impl guard(raw: builtins.str, mode: builtins.str) -> any {
    if mode == "auto" {
        mode = "html" if HTML_HINT.search(raw) else "text";
    }
    if mode == "html" {
        text: any;
        hf: any;
        (text, hf) = clean_html(raw) as any;
        hidden_text: any;
        hidden_blocks: any;
        (hidden_text, hidden_blocks) = (hf["hidden_text"], hf["hidden_blocks"]);
    } else {
        (text, hidden_text, hidden_blocks) = (raw, "", []);
    }
    tf: any;
    (text, tf) = clean_text(text) as any;
    hidden_tf: any;
    (hidden_text, hidden_tf) = clean_text(hidden_text) as any;
    for (key, n) in hidden_tf["invisible_chars"].items() {
        tf["invisible_chars"][key] = tf["invisible_chars"].get(key, 0) + n;
    }
    tf["invisible_flagged"] += hidden_tf["invisible_flagged"];
    tf["invisible_text"] += hidden_tf["invisible_text"];
    hidden_text = "\n".join([hidden_text, *tf["invisible_text"]]);
    findings: any = {"hidden_blocks": hidden_blocks, **tf, **scan(text, hidden_text)};
    verdict_line: any = verdict(findings);
    if not text and verdict_line == "posting_guard: clean" {
        findings["verdict"] = NO_TEXT_VERDICT;
    } else {
        findings["verdict"] = verdict_line;
    }
    return (text, findings);
}

impl _plain_findings(findings: builtins.dict) -> builtins.str {
    lines: any = [];
    for key in (
        "hidden_blocks",
        "instruction_like",
        "invisible_text",
        "hidden_urls",
        "homoglyph_runs",
    ) {
        items: any = findings[key];
        lines.append(f"{key} ({len(items)}):");
        lines.extend(f"  - \"{item}\"" for item in items);
    }
    lines.append(
        "invisible_chars: "
            + (", ".join(f"{k}={v}" for (k, v) in findings["invisible_chars"].items()) or "none"),
    );
    lines.append("invisible_flagged: " + format(findings["invisible_flagged"], ""));
    lines.append("visible_url_count: " + format(findings["visible_url_count"], ""));
    return "\n".join(lines);
}

impl _force_utf8_output -> None {
    for stream in (sys.stdout, sys.stderr) {
        reconfigure: any = getattr(stream, "reconfigure", None);
        if reconfigure {
            reconfigure(encoding="utf-8");
        }
    }
}

impl _read_input(path, mode) -> any {
    if path is not None {
        data: any = path.read_bytes();
    } else {
        buffer: any = getattr(sys.stdin, "buffer", None);
        if buffer is None {
            return sys.stdin.read();
        }
        data = buffer.read();
    }
    if mode == "html" {
        return decode_page(data);
    }
    return data.decode("utf-8", errors="replace");
}

impl main(argv=None) -> builtins.int {
    _force_utf8_output();
    parser: any = argparse.ArgumentParser(
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
    args: any = parser.parse_args(argv);

    try {
        raw: any = _read_input(args.infile, args.mode);
    } except OSError as exc {
        print(f"posting_guard: cannot read input: {exc}", file=sys.stderr);
        return 2;
    }

    cleaned: any;
    findings: any;
    (cleaned, findings) = guard(raw, args.mode) as any;
    print(findings["verdict"]);
    print("--- findings ---");
    print(
        json.dumps(findings, ensure_ascii=False, indent=2)
            if args.json
            else _plain_findings(findings),
    );
    if args.out is not None {
        if _inside_repo(args.out) {
            print(
                f"posting_guard: refusing to write inside the repo ({args.out}); the cleaned posting is untrusted text and belongs in the session scratchpad",
                file=sys.stderr,
            );
            return 2;
        }
        if findings["verdict"] != NO_TEXT_VERDICT {
            args.out.parent.mkdir(parents=True, exist_ok=True);
            args.out.write_text(cleaned + "\n", encoding="utf-8");
            print(f"saved={args.out}");
        }
    } else {
        print("--- text ---");
        print(cleaned);
    }
    return 1 if findings["verdict"] == NO_TEXT_VERDICT else 0;
}

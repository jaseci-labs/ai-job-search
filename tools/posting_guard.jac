"""Integrity gate for a fetched job posting: clean it, scan it, say what was found.

A posting is untrusted third-party text. The gate removes hidden HTML and invisible
characters from it, and reports what it removed together with instruction-shaped lines,
URLs that exist only in hidden content, text spelled in invisible characters and words
mixing Latin with Cyrillic or Greek letters. It advises; it never blocks.

Usage:
  neojac run jobsearch -- posting_guard [--in FILE] [--html|--text] [--out FILE] [--json]

Input is `--in FILE` or stdin; without --html or --text the mode is guessed. Output is the
verdict line, a `--- findings ---` block (JSON with --json), then `--- text ---` and the
cleaned text, or `saved=<path>` with --out. Exit 0 when a posting is evaluated, 1 when the
input has no text to evaluate, 2 when --in cannot be read or --out points inside this
repository.
"""

import argparse, html, json, os, re, sys;
import from pathlib { Path }

glob ROOT: Path = Path(os.environ.get("JOBSEARCH_ROOT") or Path(__file__).resolve().parent.parent),
     NO_TEXT_VERDICT: str = "posting_guard: refused (no text to evaluate)",
     EXCERPT: int = 120,
     LINE_MAX: int = 200,
     ZERO_WIDTH: str = "".join(
         map(chr, [0x200B, 0x200C, 0x200D, 0x2060, 0x2061, 0x2062, 0x2063, 0x2064])
     ),
     BIDI: str = "".join(
         map(chr, [0x200E, 0x200F, *range(0x202A, 0x202F), *range(0x2066, 0x206A)])
     ),
     BIDI_TAMPER: str = "".join(map(chr, [0x202D, 0x202E, 0x2066, 0x2067, 0x2068, 0x2069])),
     FORMAT: str = "".join(map(chr, [0x00AD, 0x2028, 0x2029])),
     BOM: str = chr(0xFEFF),
     TAG_BASE: int = 0xE0000,
     TAG_CHARS: str = "".join([chr(c) for c in range(TAG_BASE, TAG_BASE + 128)]),
     INVISIBLE: str = ZERO_WIDTH + BIDI + FORMAT + BOM + TAG_CHARS,
     COUNTED: dict[str, str] = {
         "zero_width": ZERO_WIDTH,
         "bidi": BIDI,
         "format": FORMAT,
         "bom": BOM,
     },
     TAG_RUN: re.Pattern[str] = re.compile("[\\U000e0000-\\U000e007f]+"),
     RGI_TAG_FLAG: re.Pattern[str] = re.compile(
         "\\U0001f3f4\\U000e0067\\U000e0062(?:\\U000e0065\\U000e006e\\U000e0067|\\U000e0073\\U000e0063\\U000e0074|\\U000e0077\\U000e006c\\U000e0073)\\U000e007f",
     ),
     VARIATION: re.Pattern[str] = re.compile("[\\ufe00-\\ufe0f\\U000e0100-\\U000e01ef]"),
     VARIATION_RUN: re.Pattern[str] = re.compile("[\\ufe00-\\ufe0f\\U000e0100-\\U000e01ef]{2,}"),
     HIDDEN_STYLE: re.Pattern[str] = re.compile(
         "(?:^|;)\\s*(?:display\\s*:\\s*none|visibility\\s*:\\s*(?:hidden|collapse)|opacity\\s*:\\s*0(?![.\\d]*[1-9])|font-size\\s*:\\s*(?:0(?:\\.0+)?(?:px|pt|em|rem|%)?(?![\\d.])|[012](?:\\.\\d+)?px(?![\\w.%]))|transform\\s*:[^;]*\\bscale(?:[XYZ]|3d)?\\(\\s*0(?![.\\d]*[1-9])|color\\s*:\\s*transparent|clip\\s*:\\s*rect\\(\\s*0|clip-path\\s*:\\s*inset\\(\\s*(?:100%|(?:5\\d|[6-9]\\d|100)(?:\\.\\d+)?%\\s*\\))|(?:(?:margin-)?(?:left|top)|text-indent)\\s*:\\s*-(?:99\\d+|\\d{4,})(?:px|em|rem))",
         re.I,
     ),
     CSS_COMMENT: re.Pattern[str] = re.compile("/\\*.*?\\*/", re.S),
     COLLAPSED_BOX: re.Pattern[str] = re.compile(
         "\\b(?:max-)?(?:height|width)\\s*:\\s*0(?:\\.0+)?(?:px|em|rem|%|pt)?(?![\\d.])", re.I
     ),
     CLIPPED: re.Pattern[str] = re.compile("\\boverflow(?:-[xy])?\\s*:\\s*hidden\\b", re.I),
     PRESTRIP: re.Pattern[str] = re.compile("<!DOCTYPE[^>]*>|<\\?[^>]*\\?>", re.I),
     COMMENT: re.Pattern[str] = re.compile("<!--.*?(?:-->|\\Z)", re.S),
     DROP_BLOCKS: re.Pattern[str] = re.compile(
         "<(script|style|noscript|svg|template)\\b[^>]*>.*?(?:</\\1\\s*>|\\Z)", re.I | re.S
     ),
     TAG: re.Pattern[str] = re.compile(
         "<(/?)([a-zA-Z][\\w:-]*)((?:[^>\\\"']|\\\"[^\\\"]*\\\"|'[^']*')*)>", re.S
     ),
     ATTR: re.Pattern[str] = re.compile(
         "([^\\s=/\\\"'>]+)(?:\\s*=\\s*(?:\\\"([^\\\"]*)\\\"|'([^']*)'|([^\\s>\\\"']+)))?"
     ),
     VOID: set[str] = set(
         "br img input meta link hr wbr source area base col embed param track".split()
     ),
     BLOCK: set[str] = set(
         (
             "p div li ul ol h1 h2 h3 h4 h5 h6 tr br section article header footer table thead tbody "
             + "blockquote pre dd dt dl nav main aside figure form fieldset legend address hr td th option"
         ).split(),
     ),
     IMPLIED_END: set[str] = {"p", "li", "dd", "dt", "tr", "td", "th", "option"},
     CLOSES_P: set[str] = BLOCK - {"br"},
     HTML_HINT: re.Pattern[str] = re.compile("<\\s*(html|body|div|p)\\b", re.I),
     URL: re.Pattern[str] = re.compile("https?://[^\\s<>\\\"')\\]]+"),
     INSTRUCTION_PATTERNS: list[re.Pattern[str]] = [
         re.compile(p, re.I)
         for p in (
             "\\bignore (all|any|the|previous|prior|above|earlier)\\b",
             "\\b(disregard|forget)( all| any| the| your| my)? (previous|prior|above|earlier|preceding|initial|original|system) (instructions?|prompts?)\\b",
             "\\byou are (?:an?|the) (?:ai(?![\\w-])|ai (?:assistant|agent|model|language model)|assistant|llm|language model)\\b",
             "\\bsystem prompt\\b",
             "\\b(do not|don['\\u2019]?t|never) (tell|inform) the user\\b(?!['\\u2019]s)",
             "\\b(do not|don['\\u2019]?t|never) (mention|reveal|disclose) (this|these|that|it|any of this|the (above|following|previous))\\b[^.\\n]{0,30}\\bto the user\\b",
             "\\b(run|execute) the following (command|commands|script|code|shell|instruction|instructions|steps)\\b",
             "\\bas an ai(?![\\w-])(?![\\s/&]+(?:[\\w&/-]+\\s+){0,3}?(?:engineer|developer|researcher|scientist|architect|specialist|lead|consultant|manager|analyst|intern|trainer|expert|strategist|designer|tester|owner|programmer)s?\\b)",
             "^\\s*(assistant|system|user)\\s*:",
             "<\\|",
             "\\[INST\\]",
             "###\\s*(system|instruction)",
             "\\b(curl|wget|ssh|scp)\\b",
             "(?<!\\bwindow)\\.env\\b",
             "settings\\.json",
             "allowed-tools",
             "\\btool_use\\b|\\bfunction_call\\b",
         )
     ],
     WORD: re.Pattern[str] = re.compile("\\w+", re.UNICODE),
     LATIN: re.Pattern[str] = re.compile("[A-Za-z]"),
     CONFUSABLE: re.Pattern[str] = re.compile("[\\u0400-\\u04ff\\u0370-\\u03ff]"),
     ALARMS: list[tuple[str, str]] = [
         ("instruction-like line", "instruction-like lines"),
         ("invisible character inside words", "invisible characters inside words"),
         (
             "tag character (text hidden from the reader)",
             "tag characters (text hidden from the reader)",
         ),
         ("string spelled in invisible characters", "strings spelled in invisible characters"),
         ("mixed-script word", "mixed-script words"),
     ],
     CONTEXT: list[tuple[str, str]] = [
         ("hidden block", "hidden blocks"),
         ("hidden URL", "hidden URLs"),
     ],
     LISTED: tuple[str, ...] = (
         "hidden_blocks",
         "instruction_like",
         "invisible_text",
         "hidden_urls",
         "homoglyph_runs",
     );

"""True when `path` would land inside this repository, compared by file identity."""
def _inside_repo(path: Path) -> bool {
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

def _fold(text: str) -> str {
    text = text.replace("\r\n", "\n").replace("\r", "\n");
    text = re.sub("[ \\t\\xa0\\f\\v]+", " ", text);
    text = re.sub(" *\\n *", "\n", text);
    return re.sub("\\n{3,}", "\n\n", text).strip();
}

def _tag_text(run: str) -> str {
    return "".join([chr(ord(c) - TAG_BASE) for c in run if 32 <= ord(c) - TAG_BASE < 127]);
}

def _selector_text(run: str) -> str {
    data: bytes = bytes([
        ord(c) - 0xFE00 if ord(c) <= 0xFE0F else ord(c) - 0xE0100 + 16
        for c in run
    ]);
    return "".join([c for c in data.decode("utf-8", errors="replace") if c.isprintable()]);
}

"""Text without invisible characters, with their counts, the tampering count and what they spelled."""
def clean_text(text: str) -> tuple[str, dict[str, any]] {
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

def _attrs(raw: str) -> dict[str, str] {
    return {
        m.group(1).lower(): "" if m.lastindex == 1 else m.group(m.lastindex)
        for m in ATTR.finditer(raw)
    };
}

"""True when a tag's attributes hide it, the style read as a browser reads it."""
def _is_hidden(raw_attrs: str) -> bool {
    attrs: dict[str, str] = _attrs(raw_attrs);
    if "hidden" in attrs or attrs.get("aria-hidden", "").strip().lower() == "true" {
        return True;
    }
    style: str = CSS_COMMENT.sub("", html.unescape(attrs.get("style", "")));
    return bool(
        HIDDEN_STYLE.search(style) or (COLLAPSED_BOX.search(style) and CLIPPED.search(style))
    );
}

"""Visible text of a page, with excerpts of its hidden elements and everything removed."""
def clean_html(markup: str) -> tuple[str, dict[str, any]] {
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

"""Up to LINE_MAX characters of `line`, always including position `at`."""
def _excerpt(line: str, at: int) -> str {
    if len(line) <= LINE_MAX {
        return line;
    }
    end: int = min(len(line), max(0, at - LINE_MAX // 3) + LINE_MAX);
    start: int = max(0, end - LINE_MAX);
    return ("…" if start else "") + line[start:end] + ("…" if end < len(line) else "");
}

def _instruction_at(line: str) -> int | None {
    for pattern in INSTRUCTION_PATTERNS {
        found: re.Match[str] | None = pattern.search(line);
        if found {
            return found.start();
        }
    }
    return None;
}

"""Instruction-shaped lines, hidden URLs, visible URL count, mixed-script words."""
def scan(visible: str, hidden: str) -> dict[str, any] {
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

def _phrases(counts: list[int], names: list[tuple[str, str]]) -> list[str] {
    return [f"{n} {one if n == 1 else many}" for (n, (one, many)) in zip(counts, names) if n];
}

def verdict(findings: dict[str, any]) -> str {
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

"""Run the whole gate in mode "html", "text" or "auto": the cleaned text and the findings."""
def guard(raw: str, mode: str) -> tuple[str, dict[str, any]] {
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

def _plain_findings(findings: dict[str, any]) -> str {
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

def _force_utf8_output -> None {
    for stream in (sys.stdout, sys.stderr) {
        reconfigure: any = getattr(stream, "reconfigure", None);
        if reconfigure {
            reconfigure(encoding="utf-8");
        }
    }
}

def _read_input(path: Path | None, mode: str) -> str {
    buffer: any = getattr(sys.stdin, "buffer", None);
    if path is None and buffer is None {
        return sys.stdin.read();
    }
    data: bytes = buffer.read() if path is None else path.read_bytes();
    return decode_page(data) if mode == "html" else data.decode("utf-8", errors="replace");
}

def main(argv: list[str] | None = None) -> int {
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

with entry:__main__ {
    sys.exit(main());
}

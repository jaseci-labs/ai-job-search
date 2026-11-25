impl VerificationError.__repr__ -> str {
    return (getattr(builtins.super(VerificationError, self), "__repr__") as any)();
}

impl VerificationError.__eq__(other: any) -> bool {
    return self is other;
}

impl VerificationError.__hash__ -> int {
    return id(self);
}

impl check_dump_target(path, `root=root_default_) -> any {
    parent: any;
    path = Path(path);
    if path.suffix != ".txt" {
        return "must name a .txt file";
    }
    if path.is_symlink() {
        return "must not be a symlink";
    }
    parent = path.resolve().parent;
    if not `any(parent.is_relative_to((`root / d).resolve()) for d in DUMP_TEXT_DIRS) {
        return "must be inside this repo's " + " or ".join(f"{d}/" for d in DUMP_TEXT_DIRS);
    }
    return None;
}

impl run_tool(command) -> any {
    try {
        return subprocess.run(
            command, check=True, capture_output=True, text=True, encoding="utf-8", errors="replace"
        ).stdout;
    } except FileNotFoundError as exc {
        raise VerificationError(
            f"required command '{command[0]}' was not found. Install pypdf (`neojac install`) or poppler-utils (macOS: brew install poppler, Debian/Ubuntu: apt install poppler-utils, Windows: choco install poppler)",
        ) from exc;
    } except subprocess.CalledProcessError as exc {
        detail: any = (exc.stderr or "").strip() or (exc.stdout or "").strip();
        detail = detail or "command failed";
        raise VerificationError(f"{command[0]} could not read the PDF: {detail}") from exc;
    }
}

impl parse_page_count(pdfinfo_output) -> any {
    `match: any = re.search("^Pages:\\s+(\\d+)\\s*$", pdfinfo_output, re.MULTILINE);
    if not `match {
        raise VerificationError("pdfinfo output did not contain a page count");
    }
    return `int(`match.group(1));
}

impl normalize_text(text) -> any {
    text = unicodedata.normalize("NFC", text).translate(TYPOGRAPHIC_FOLDS);
    return " ".join(text.split());
}

impl _bare_number(token) -> any {
    core: any = token.strip(_OUTER_PUNCTUATION);
    if not _BARE_NUMBER.fullmatch(core) {
        return None;
    }
    groups: any = re.split("[.,]", core.rstrip("kKmM%"));
    if len(groups) > 1 and `any(_BARE_YEAR.fullmatch(g) for g in groups) {
        return None;
    }
    return core;
}

impl _currency_amount(token) -> any {
    core: any = token.strip(_OUTER_PUNCTUATION);
    if core and unicodedata.category(core[0]) == "Sc" {
        core = core[1:];
    } elif core and unicodedata.category(core[-1]) == "Sc" {
        core = core[:-1];
    } else {
        return None;
    }
    return core if _BARE_NUMBER.fullmatch(core) else None;
}

impl _quantity_range(line, dash_index) -> any {
    before: any = _TOKEN_BEFORE.search(line[:dash_index]);
    after: any = _TOKEN_AFTER.search(line[dash_index + 1:]);
    if not before or not after {
        return False;
    }
    left_money: any;
    right_money: any;
    (left_money, right_money) = (
        _currency_amount(before.group(1)),
        _currency_amount(after.group(1)),
    );
    left: any;
    right: any;
    (left, right) = (
        left_money or _bare_number(before.group(1)),
        right_money or _bare_number(after.group(1)),
    );
    if left_money is not None or right_money is not None {
        return left is not None and right is not None;
    }
    if left is None or right is None {
        return False;
    }
    if _BARE_YEAR.fullmatch(left)
        and (_BARE_YEAR.fullmatch(right) or _TWO_DIGIT_YEAR.fullmatch(right))
    {
        return False;
    }
    return True;
}

impl find_non_ascii_date_ranges(text) -> any {
    hits: any = [];
    for `match in NON_ASCII_DATE_RANGE.finditer(text) {
        dash: any = next(c for c in `match.group(0) if c in NON_ASCII_DASHES);
        line_start: any = text.rfind("\n", 0, `match.start()) + 1;
        line_end: any = text.find("\n", `match.end());
        line_end = line_end if line_end != -1 else len(text);
        line: any = text[line_start:line_end];
        if _quantity_range(line, `match.start() + `match.group(0).index(dash) - line_start) {
            continue;
        }
        hits.append((" ".join(line.split()), dash));
    }
    return hits;
}

impl _extract_pypdf(pdf_path) -> any {
    try {
        import from pypdf { PdfReader }
    } except ImportError {
        return None;
    }
    try {
        reader: any = PdfReader(`str(pdf_path));
        pages: any = len(reader.pages);
        text: any = "\n".join(page.extract_text() or "" for page in reader.pages);
    } except Exception {
        return None;
    }
    if len(normalize_text(text)) == 0 {
        return None;
    }
    return (text, pages);
}

impl _extract_pdftotext(pdf_path) -> any {
    text: any = run_tool(["pdftotext", "-layout", "-enc", "UTF-8", `str(pdf_path), "-"]);
    pages: any = parse_page_count(run_tool(["pdfinfo", `str(pdf_path)]));
    return (text, pages);
}

impl extract_text_layer(pdf_path) -> any {
    pypdf_result: any = _extract_pypdf(pdf_path);
    if pypdf_result is not None {
        text: any;
        pages: any;
        (text, pages) = pypdf_result as any;
        return (text, pages, "pypdf");
    }
    (text, pages) = _extract_pdftotext(pdf_path) as any;
    return (text, pages, "pdftotext");
}

impl verify_pdf(
    pdf_path, expected_pages=None, min_chars=1, required_text=(), dump_text=None, ascii_dates=False
) -> any {
    pdf_path = Path(pdf_path);
    if not pdf_path.is_file() {
        raise VerificationError(f"PDF does not exist: {pdf_path}");
    }

    extracted_text: any;
    actual_pages: any;
    extractor: any;
    (extracted_text, actual_pages, extractor) = extract_text_layer(pdf_path) as any;
    if dump_text is not None {
        dump_path: any = Path(dump_text);
        try {
            dump_path.parent.mkdir(parents=True, exist_ok=True);
            dump_path.write_text(
                extracted_text if extracted_text.endswith("\n") else extracted_text + "\n",
                encoding="utf-8",
            );
        } except OSError as exc {
            raise VerificationError(f"could not write --dump-text to {dump_path}: {exc}") from exc;
        }
    }

    if expected_pages is not None and actual_pages != expected_pages {
        raise VerificationError(
            f"expected {expected_pages} page(s), found {actual_pages} (extractor: {extractor})"
        );
    }

    normalized: any = normalize_text(extracted_text);
    if len(normalized) < min_chars {
        raise VerificationError(
            f"text layer has {len(normalized)} character(s); expected at least {min_chars} (extractor: {extractor})",
        );
    }

    for required in required_text {
        if normalize_text(required) not in normalized {
            raise VerificationError(
                f"text layer is missing required text: {required!r} (extractor: {extractor})"
            );
        }
    }

    if ascii_dates {
        hits: any = find_non_ascii_date_ranges(extracted_text);
        if hits {
            listed: any = "; ".join(f"U+{ord(dash):04X} in {line[:80]!r}" for (line, dash) in hits);
            raise VerificationError(
                f"{len(hits)} date range(s) joined by a non-ASCII dash - an ATS that splits ranges on U+002D drops the date; write the date argument with a single ASCII hyphen (05-cv-templates.md, 'Date fields must be ASCII ranges'): {listed} (extractor: {extractor})",
            );
        }
    }
    return (extractor, extracted_text, actual_pages);
}

impl build_parser -> any {
    parser: any = argparse.ArgumentParser(
        description="Verify a PDF's page count and ATS-readable text layer."
    );
    parser.add_argument("pdf", type=Path, help="PDF file to verify");
    parser.add_argument("--pages", type=int, help="required exact page count");
    parser.add_argument(
        "--min-chars",
        type=int,
        default=1,
        help="minimum non-whitespace text-layer characters (default: 1)",
    );
    parser.add_argument(
        "--contains",
        action="append",
        default=[],
        help="text that must appear in the text layer; both sides are folded for whitespace, NFC, and LaTeX's typographic substitutions (curly apostrophes/quotes, en/em dashes, no-break spaces); repeatable",
    );
    parser.add_argument(
        "--dump-text",
        type=Path,
        help="write the extracted text layer to this .txt path under cv/ or cover_letters/ (UTF-8)",
    );
    parser.add_argument(
        "--ascii-dates",
        action="store_true",
        help="fail if the raw text layer has a year joined to a Unicode dash (the en-dash LaTeX makes from --), which ATS date parsers drop; this check never folds, unlike --contains",
    );
    return parser;
}

impl _force_utf8_output -> None {
    for stream in (sys.stdout, sys.stderr) {
        reconfigure: any = getattr(stream, "reconfigure", None);
        if reconfigure {
            reconfigure(encoding="utf-8");
        }
    }
}

impl main(argv=None) -> any {
    _force_utf8_output();
    args: any = build_parser().parse_args(argv);
    if args.dump_text is not None {
        reason: any = check_dump_target(args.dump_text);
        if reason {
            print(f"Error: --dump-text {args.dump_text}: {reason}", file=sys.stderr);
            return 1;
        }
    }
    try {
        extractor: any;
        text: any;
        pages: any;
        (extractor, text, pages) = verify_pdf(
            args.pdf,
            args.pages,
            args.min_chars,
            args.contains,
            dump_text=args.dump_text,
            ascii_dates=args.ascii_dates,
        ) as any;
    } except VerificationError as exc {
        print(f"Error: {args.pdf}: {exc}", file=sys.stderr);
        return 1;
    }
    print(f"Verified {args.pdf} (extractor: {extractor}, pages: {pages})");
    return 0;
}

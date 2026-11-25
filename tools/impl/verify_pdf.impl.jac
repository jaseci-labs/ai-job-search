impl check_dump_target(path: str | Path, base: Path = ROOT) -> str | None {
    target: Path = Path(path);
    if target.suffix != ".txt" {
        return "must name a .txt file";
    }
    if target.is_symlink() {
        return "must not be a symlink";
    }
    parent: Path = target.resolve().parent;
    if not any([parent.is_relative_to((base / d).resolve()) for d in DUMP_TEXT_DIRS]) {
        return "must be inside this repo's " + " or ".join([f"{d}/" for d in DUMP_TEXT_DIRS]);
    }
    return None;
}

impl run_tool(command: list[str]) -> str {
    try {
        return subprocess.run(
            command, check=True, capture_output=True, text=True, encoding="utf-8", errors="replace"
        ).stdout;
    } except FileNotFoundError as exc {
        raise VerificationError(
            f"required command '{command[0]}' was not found. Install pypdf (`neojac install`) or poppler-utils (macOS: brew install poppler, Debian/Ubuntu: apt install poppler-utils, Windows: choco install poppler)",
        ) from exc;
    } except subprocess.CalledProcessError as exc {
        detail: str = (exc.stderr or "").strip() or (exc.stdout or "").strip() or "command failed";
        raise VerificationError(f"{command[0]} could not read the PDF: {detail}") from exc;
    }
}

impl parse_page_count(pdfinfo_output: str) -> int {
    found: any = re.search("^Pages:\\s+(\\d+)\\s*$", pdfinfo_output, re.MULTILINE);
    if not found {
        raise VerificationError("pdfinfo output did not contain a page count");
    }
    return int(found.group(1));
}

impl normalize_text(text: str) -> str {
    return " ".join(unicodedata.normalize("NFC", text).translate(TYPOGRAPHIC_FOLDS).split());
}

impl _bare_number(token: str) -> str | None {
    core: str = token.strip(OUTER_PUNCTUATION);
    groups: list[str] = re.split("[.,]", core.rstrip("kKmM%"));
    dated: bool = len(groups) > 1 and any([BARE_YEAR.fullmatch(g) for g in groups]);
    return core if BARE_NUMBER.fullmatch(core) and not dated else None;
}

impl _currency_amount(token: str) -> str | None {
    core: str = token.strip(OUTER_PUNCTUATION);
    if core and unicodedata.category(core[0]) == "Sc" {
        core = core[1:];
    } elif core and unicodedata.category(core[-1]) == "Sc" {
        core = core[:-1];
    } else {
        return None;
    }
    return core if BARE_NUMBER.fullmatch(core) else None;
}

impl _quantity_range(line: str, dash_index: int) -> bool {
    before: any = TOKEN_BEFORE.search(line[:dash_index]);
    after: any = TOKEN_AFTER.search(line[dash_index + 1:]);
    if not before or not after {
        return False;
    }
    left_money: str | None = _currency_amount(before.group(1));
    right_money: str | None = _currency_amount(after.group(1));
    left: str | None = left_money or _bare_number(before.group(1));
    right: str | None = right_money or _bare_number(after.group(1));
    if left is None or right is None {
        return False;
    }
    if left_money or right_money {
        return True;
    }
    return not (
        BARE_YEAR.fullmatch(left)
        and (BARE_YEAR.fullmatch(right) or TWO_DIGIT_YEAR.fullmatch(right))
    );
}

impl find_non_ascii_date_ranges(text: str) -> list[tuple[str, str]] {
    hits: list[tuple[str, str]] = [];
    for found in NON_ASCII_DATE_RANGE.finditer(text) {
        span: str = found.group(0);
        dash: str = [c for c in span if c in NON_ASCII_DASHES][0];
        line_start: int = text.rfind("\n", 0, found.start()) + 1;
        line_end: int = text.find("\n", found.end());
        line: str = text[line_start:] if line_end == -1 else text[line_start:line_end];
        if not _quantity_range(line, found.start() + span.index(dash) - line_start) {
            hits.append((" ".join(line.split()), dash));
        }
    }
    return hits;
}

impl _extract_pypdf(pdf_path: Path) -> tuple[str, int] | None {
    try {
        import from pypdf { PdfReader }
    } except ImportError {
        return None;
    }
    try {
        reader: any = PdfReader(str(pdf_path));
        text: str = "\n".join([page.extract_text() or "" for page in reader.pages]);
        return (text, len(reader.pages)) if normalize_text(text) else None;
    } except Exception {
        return None;
    }
}

impl extract_text_layer(pdf_path: Path) -> tuple[str, int, str] {
    found: tuple[str, int] | None = _extract_pypdf(pdf_path);
    if found is not None {
        return (found[0], found[1], "pypdf");
    }
    text: str = run_tool(["pdftotext", "-layout", "-enc", "UTF-8", str(pdf_path), "-"]);
    return (text, parse_page_count(run_tool(["pdfinfo", str(pdf_path)])), "pdftotext");
}

impl verify_pdf(
    pdf_path: str | Path,
    expected_pages: int | None = None,
    min_chars: int = 1,
    required_text: any = (),
    dump_text: str | Path | None = None,
    ascii_dates: bool = False,
) -> tuple[str, str, int] {
    pdf: Path = Path(pdf_path);
    if not pdf.is_file() {
        raise VerificationError(f"PDF does not exist: {pdf}");
    }
    (text, pages, extractor) = extract_text_layer(pdf);
    if dump_text is not None {
        dump_path: Path = Path(dump_text);
        try {
            dump_path.parent.mkdir(parents=True, exist_ok=True);
            dump_path.write_text(text if text.endswith("\n") else text + "\n", encoding="utf-8");
        } except OSError as exc {
            raise VerificationError(f"could not write --dump-text to {dump_path}: {exc}") from exc;
        }
    }
    if expected_pages is not None and pages != expected_pages {
        raise VerificationError(
            f"expected {expected_pages} page(s), found {pages} (extractor: {extractor})"
        );
    }
    normalized: str = normalize_text(text);
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
    hits: list[tuple[str, str]] = find_non_ascii_date_ranges(text) if ascii_dates else [];
    if hits {
        listed: str = "; ".join([f"U+{ord(dash):04X} in {line[:80]!r}" for (line, dash) in hits]);
        raise VerificationError(
            f"{len(hits)} date range(s) joined by a non-ASCII dash - an ATS that splits ranges on U+002D drops the date; write the date argument with a single ASCII hyphen (05-cv-templates.md, 'Date fields must be ASCII ranges'): {listed} (extractor: {extractor})",
        );
    }
    return (extractor, text, pages);
}

impl build_parser -> argparse.ArgumentParser {
    parser: argparse.ArgumentParser = argparse.ArgumentParser(
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

impl main(argv: list[str] | None = None) -> int {
    _force_utf8_output();
    args: any = build_parser().parse_args(argv);
    reason: str | None = None if args.dump_text is None else check_dump_target(args.dump_text);
    if reason {
        print(f"Error: --dump-text {args.dump_text}: {reason}", file=sys.stderr);
        return 1;
    }
    try {
        (extractor, _, pages) = verify_pdf(
            args.pdf,
            args.pages,
            args.min_chars,
            args.contains,
            dump_text=args.dump_text,
            ascii_dates=args.ascii_dates,
        );
    } except VerificationError as exc {
        print(f"Error: {args.pdf}: {exc}", file=sys.stderr);
        return 1;
    }
    print(f"Verified {args.pdf} (extractor: {extractor}, pages: {pages})");
    return 0;
}

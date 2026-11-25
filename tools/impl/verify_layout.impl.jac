impl Page.init(height: float, lines: list[Line]) {
    self.height = height;
    self.lines = sorted(lines, key=lambda (l) -> any { l.top });
}

impl Page.is_indented(line: Line) -> bool {
    return operator.gt(line.left, self.left_edge + INDENT_PT);
}

impl Page.is_heading(line: Line) -> bool {
    median: any = self.body_median_height;
    return `bool(median) and operator.gt(line.height, median * HEADING_HEIGHT_RATIO);
}

impl Page.largest_gap -> tuple[float, float] {
    tops: any;
    tops = sorted({round(l.top, 1) for l in self.body});
    if len(tops) < 2 {
        return (0.0, 0.0);
    }
    return max((tops[i + 1] - tops[i], tops[i]) for i in range(len(tops) - 1));
}

impl Page.__repr__ -> str {
    return (getattr(builtins.object, "__repr__") as any)(self);
}

impl Page.__eq__(other: any) -> bool {
    return self is other;
}

impl Page.__hash__ -> int {
    return id(self);
}

impl find_pdftotext -> str | None {
    candidates: list[str] = [];
    seen: set[str] = set[any]();
    for `entry in os.get_exec_path() {
        candidate: any = shutil.which("pdftotext", path=`entry);
        if candidate and candidate not in seen {
            seen.add(candidate);
            candidates.append(candidate);
        }
    }
    if not candidates {
        return None;
    }
    for candidate in candidates {
        try {
            res: any = subprocess.run(
                [candidate, "-h"],
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
            );
            output: any = (res.stdout or "") + (res.stderr or "");
            if "-bbox" in output {
                return candidate;
            }
        } except (subprocess.SubprocessError, OSError) {
            continue;
        }
    }
    return candidates[0];
}

impl parse_pdf(path: Path) -> list[Page] {
    binary: any = find_pdftotext();
    if not binary {
        raise RuntimeError("pdftotext (Poppler) not found; install poppler-utils");
    }
    try {
        out: any = subprocess.run(
            [binary, "-bbox", "-enc", "UTF-8", `str(path), "-"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            check=True,
        ).stdout;
    } except subprocess.CalledProcessError as exc {
        stderr_lines: any = (exc.stderr or "").strip().splitlines();
        detail: any = stderr_lines[0] if stderr_lines else f"exit {exc.returncode}";
        raise RuntimeError(
            f"pdftotext could not produce bounding boxes for {path} ({detail}); either no pdftotext on PATH has the -bbox flag (Git for Windows ships an xpdf build without it), or Poppler aborted on this document - Poppler 26.0x before 26.05 aborts on a PDF whose Info dictionary carries an empty string, as hyperref writes when pdftitle is unset",
        ) from exc;
    }
    pages: any = [];
    for (_w, h, body) in PAGE_RE.findall(out) {
        buckets: dict[float, list[tuple[float, float, float, str]]] = {};
        for (x_min, y_min, y_max, text) in WORD_RE.findall(body) {
            key: any = round(`float(y_min), 0);
            buckets.setdefault(key, []).append((`float(x_min), `float(y_min), `float(y_max), text));
        }
        lines: any = [
            Line(
                top=min(w[1] for w in words),
                bottom=max(w[2] for w in words),
                left=min(w[0] for w in words),
                height=max(w[2] - w[1] for w in words),
                text=" ".join(w[3] for w in sorted(words)),
                text_left=text_start(sorted(words)),
            )
            for words in buckets.values()
        ];
        pages.append(Page(`float(h), lines));
    }
    return pages;
}

impl text_start(words: list[tuple[float, float, float, str]]) -> float | None {
    lead: any = 0;
    while lead < len(words) and words[lead][3] and `set(words[lead][3]) <= LIST_MARKERS {
        lead += 1;
    }
    return words[lead][0] if 0 < lead < len(words) else None;
}

impl printed_text_x(lines: list[Line]) -> float | None {
    xs: any = [l.text_x for l in lines if TEXT_RE.search(l.text)];
    return min(xs) if xs else None;
}

impl find_orphans(pages: list[Page]) -> list[str] {
    doc_left: any;
    problems: any = [];
    body_lines: any = [l for p in pages for l in p.body];
    if not body_lines {
        return problems;
    }
    doc_left = min(l.left for l in body_lines);

    def indented(line: Line) -> bool {
        return operator.gt(line.left, doc_left + INDENT_PT);
    }

    for i in range(len(pages) - 1) {
        `here: any;
        nxt: any;
        (`here, nxt) = (pages[i], pages[i + 1]);
        if `here.empty or nxt.empty {
            continue;
        }
        last: any;
        first: any;
        (last, first) = (`here.body[-1], nxt.body[0]);

        if `here.is_heading(last) {
            problems.append(
                f"p{i + 1} ends on the section heading {last.text.strip()!r} with its content on p{i + 2}. Shorten the entry that follows it, or let the heading and its first entry move to the next page together",
            );
            continue;
        }
        tail: any = [l for l in `here.body if l.top >= last.top - SAME_PRINTED_LINE_PT];
        last_x: any = printed_text_x(tail);
        if last_x is None {
            if not indented(last) and indented(first) {
                problems.append(
                    f"p{i + 1} ends on a lone list marker whose text continues on p{i + 2} ({first.text.strip()[:60]!r}): a bullet is split across the page break. Shorten the preceding content so the whole item fits on one page",
                );
            }
            continue;
        }
        opener: any = next(
            (l
            for l in nxt.body
            if TEXT_RE.search(l.text) and l.text_x <= doc_left + SET_IN_LIMIT_PT),
            None,
        );
        if opener is None {
            continue;
        }
        head: any = [l for l in nxt.body if abs(l.top - opener.top) <= SAME_PRINTED_LINE_PT];
        next_x: any = printed_text_x(head);
        if next_x is not None and next_x > last_x + INDENT_PT {
            shown: any = max(
                (l for l in tail if TEXT_RE.search(l.text)), key=lambda (l) -> any { len(l.text) }
            );
            problems.append(
                f"p{i + 1} ends on {shown.text.strip()[:60]!r} while the text on p{i + 2} starts further in ({opener.text.strip()[:60]!r}): an entry header is orphaned from its bullets. Add \\needspace before that \\cventry, or shorten it",
            );
        }
    }
    return problems;
}

impl `report(path: Path, pages: list[Page]) -> list[str] {
    problems: list[str] = [];
    print(f"{path}: {len(pages)} page(s) (page count is verify_pdf.jac's job, not checked here)");

    for (i, page) in enumerate(pages, 1) {
        if page.empty {
            problems.append(f"p{i} contains no text");
            print(f"  p{i}: EMPTY");
            continue;
        }

        gap: any;
        gap_y: any;
        (gap, gap_y) = page.largest_gap() as any;
        share: any = page.bottom_space / page.height;
        print(
            f"  p{i}: text y {page.body[0].top:.0f}..{page.body[-1].bottom:.0f} of {page.height:.0f}pt | bottom {page.bottom_space:.0f}pt ({share * 100:.0f}%) | largest gap {gap:.0f}pt at y{gap_y:.0f}",
        );

        if gap > GAP_LIMIT_PT {
            problems.append(
                f"p{i} has a {gap:.0f}pt hole at y{gap_y:.0f} (~{gap / 14:.0f} blank lines). A moderncv \\cventry is an unbreakable tabular: shorten the entry that follows the hole so it fits, or move a shorter section above it",
            );
        }
        if i < len(pages) and share > BOTTOM_LIMIT_FRACTION {
            problems.append(
                f"p{i} ends {page.bottom_space:.0f}pt ({share * 100:.0f}%) early although more pages follow, which reads as a broken page break",
            );
        }
        if page.footer_crowded {
            problems.append(
                f"p{i} has body text inside the bottom margin band, colliding with the footer; stop stretching the page with \\enlargethispage and cut content",
            );
        }
        if i == len(pages) > 1 and share > LAST_PAGE_THIN_FRACTION {
            problems.append(
                f"p{i} is the last page and {share * 100:.0f}% empty, which reads as an unfinished document; restore the highest-relevance content previously cut",
            );
        }
    }

    problems.extend(find_orphans(pages));
    return problems;
}

impl _force_utf8_output -> None {
    for stream in (sys.stdout, sys.stderr) {
        reconfigure: any = getattr(stream, "reconfigure", None);
        if reconfigure {
            reconfigure(encoding="utf-8");
        }
    }
}

impl main -> int {
    _force_utf8_output();
    ap: any = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    );
    ap.add_argument("pdf", nargs="?", type=Path);
    args: any = ap.parse_args();

    if not args.pdf {
        ap.error("pdf is required");
    }
    if not args.pdf.exists() {
        print(f"error: {args.pdf} not found", file=sys.stderr);
        return 2;
    }

    try {
        pages: any = parse_pdf(args.pdf);
    } except RuntimeError as exc {
        print(f"skipped: {exc}", file=sys.stderr);
        return 2;
    }

    problems: any = `report(args.pdf, pages);
    if problems {
        print("\nLAYOUT PROBLEMS:");
        for m in problems {
            print(f"  - {m}");
        }
        return 1;
    }
    print("layout: clean");
    return 0;
}

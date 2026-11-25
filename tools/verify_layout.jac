"""Measure a compiled CV or cover letter's page layout, instead of eyeballing it.

Each failure below compiles cleanly, has the right page count and passes `tools/verify_pdf.jac`:

  orphaned entry      A page ends on a \\cventry header or a section heading whose content
                      resumes on the next page.
  internal hole       The space an ejected entry leaves behind mid-page.
  page ends early     A non-final page that stops well short of the bottom.
  final page thin     A last page mostly empty, which reads as an unfinished document.
  footer collision    Body text pushed into the page-number band, the usual result of
                      rescuing a page with \\enlargethispage or a negative \\vspace.

Page count is deliberately NOT checked here: `tools/verify_pdf.jac --pages` already does that.

Geometry comes from Poppler word bounding boxes (`pdftotext -bbox`), which pypdf cannot give.
Without Poppler, or with an extractor that cannot produce them, the check reports `skipped:`
and exits 2 rather than inventing a layout failure.

The thresholds are calibrated for the stock moderncv (`cv/`) and cover.cls (`cover_letters/`)
geometry; a template registered via `/add-template` may need them retuned.

Usage:
    neojac run jobsearch -- verify_layout cv/main_acme_ml_engineer.pdf
    neojac run jobsearch -- verify_layout cover_letters/cover_acme_ml_engineer.pdf

Exit codes: 0 clean, 1 layout problem, 2 bad invocation or no usable extractor.

The shipped `cv/main_example.pdf` exits 1 by design: its placeholder page 2 is mostly empty.
"""

import argparse, functools, os, re, shutil, subprocess, sys;
import from pathlib { Path }

glob GAP_LIMIT_PT: float = 100.0,
     BOTTOM_LIMIT_FRACTION: float = 0.25,
     LAST_PAGE_THIN_FRACTION: float = 0.35,
     FOOTER_BAND_PT: float = 90.0,
     INDENT_PT: float = 8.0,
     LIST_MARKERS: frozenset[str] = frozenset("•‣▪●·"),
     SAME_PRINTED_LINE_PT: float = 3.0,
     SET_IN_LIMIT_PT: float = 60.0,
     HEADING_HEIGHT_RATIO: float = 1.25,
     PAGE_RE: re.Pattern = re.compile(
         "<page width=\"([\\d.]+)\" height=\"([\\d.]+)\">(.*?)</page>", re.S
     ),
     WORD_RE: re.Pattern = re.compile(
         "<word xMin=\"([\\d.]+)\" yMin=\"([\\d.]+)\" xMax=\"[\\d.]+\" yMax=\"([\\d.]+)\">([^<]*)</word>",
     ),
     TEXT_RE: re.Pattern = re.compile("\\w");

"""One bounding-box line; `text_left` is where its text starts when a list marker leads it."""
obj Line {
    has top: float,
        bottom: float,
        left: float,
        height: float,
        text: str,
        text_left: float | None = None;

    has text_x: float {
        getter {
            return self.left if self.text_left is None else self.text_left;
        }
    }
}

obj Page {
    has height: float,
        lines: list[Line];

    def postinit {
        self.lines = sorted(self.lines, key=lambda (l: Line) -> float { l.top });
    }

    """The lines above the footer band."""
    has body: list[Line] {
        getter {
            return [l for l in self.lines if l.top < self.height - FOOTER_BAND_PT];
        }
    }

    has empty: bool {
        getter {
            return not self.body;
        }
    }

    has bottom_space: float {
        getter {
            return self.height - max([l.bottom for l in self.body], default=0.0);
        }
    }

    has left_edge: float {
        getter {
            return min([l.left for l in self.body], default=0.0);
        }
    }

    """One line in the bottom band is a page number; two means body text spilled in."""
    has footer_crowded: bool {
        getter {
            band: float = self.height - FOOTER_BAND_PT;
            return len({round(l.top, 1) for l in self.lines if l.top >= band}) > 1;
        }
    }

    def is_indented(line: Line) -> bool {
        return line.left > self.left_edge + INDENT_PT;
    }

    def is_heading(line: Line) -> bool {
        heights: list[float] = sorted([l.height for l in self.body]);
        median: float = heights[len(heights) // 2] if heights else 0.0;
        return bool(median) and line.height > median * HEADING_HEIGHT_RATIO;
    }

    """Largest top-to-top distance between body lines, and the top it starts at."""
    def largest_gap -> tuple[float, float] {
        tops: list[float] = sorted({round(l.top, 1) for l in self.body});
        return max([(b - a, a) for (a, b) in zip(tops, tops[1:])], default=(0.0, 0.0));
    }
}

"""The first pdftotext on PATH that advertises -bbox, else the first one, else None."""
def _find_pdftotext -> str | None {
    found: list[str | None] = [shutil.which("pdftotext", path=d) for d in os.get_exec_path()];
    candidates: list[str] = list(dict.fromkeys([c for c in found if c]));
    for candidate in candidates {
        try {
            res: any = subprocess.run(
                [candidate, "-h"],
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
            );
            if "-bbox" in (res.stdout or "") + (res.stderr or "") {
                return candidate;
            }
        } except (subprocess.SubprocessError, OSError) {
            continue;
        }
    }
    return candidates[0] if candidates else None;
}

"""`_find_pdftotext`, worked out once a run."""
glob find_pdftotext: any = functools.cache(_find_pdftotext);

def parse_pdf(path: Path) -> list[Page] {
    binary: str | None = find_pdftotext();
    if not binary {
        raise RuntimeError("pdftotext (Poppler) not found; install poppler-utils");
    }
    try {
        out: str = subprocess.run(
            [binary, "-bbox", "-enc", "UTF-8", str(path), "-"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            check=True,
        ).stdout;
    } except subprocess.CalledProcessError as exc {
        stderr_lines: list[str] = (exc.stderr or "").strip().splitlines();
        detail: str = stderr_lines[0] if stderr_lines else f"exit {exc.returncode}";
        raise RuntimeError(
            f"pdftotext could not produce bounding boxes for {path} ({detail}); either no pdftotext on PATH has the -bbox flag (Git for Windows ships an xpdf build without it), or Poppler aborted on this document - Poppler 26.0x before 26.05 aborts on a PDF whose Info dictionary carries an empty string, as hyperref writes when pdftitle is unset",
        ) from exc;
    }
    pages: list[Page] = [];
    for (_, page_height, body) in PAGE_RE.findall(out) {
        buckets: dict[float, list[tuple[float, float, float, str]]] = {};
        for (x_min, y_min, y_max, text) in WORD_RE.findall(body) {
            buckets.setdefault(round(float(y_min), 0), []).append((
                float(x_min),
                float(y_min),
                float(y_max),
                text,
            ));
        }
        lines: list[Line] = [];
        for unsorted in buckets.values() {
            words: list[tuple[float, float, float, str]] = sorted(unsorted);
            lines.append(
                Line(
                    top=min([w[1] for w in words]),
                    bottom=max([w[2] for w in words]),
                    left=words[0][0],
                    height=max([w[2] - w[1] for w in words]),
                    text=" ".join([w[3] for w in words]),
                    text_left=text_start(words),
                ),
            );
        }
        pages.append(Page(float(page_height), lines));
    }
    return pages;
}

"""xMin of the first word after leading LIST_MARKERS words, if there were any."""
def text_start(words: list[tuple[float, float, float, str]]) -> float | None {
    lead: int = 0;
    while lead < len(words) and words[lead][3] and set(words[lead][3]) <= LIST_MARKERS {
        lead += 1;
    }
    return words[lead][0] if 0 < lead < len(words) else None;
}

"""Where the text of one printed line starts, from the bbox lines that make it up."""
def printed_text_x(lines: list[Line]) -> float | None {
    xs: list[float] = [l.text_x for l in lines if TEXT_RE.search(l.text)];
    return min(xs) if xs else None;
}

"""Page breaks that strand a section heading, an entry header or a list marker.

An entry header is found by where the TEXT of the lines on either side of the break starts,
not by their left edge: a list marker merged into a line moves its edge but not its text.
"""
def find_orphans(pages: list[Page]) -> list[str] {
    problems: list[str] = [];
    doc_left: float = min([l.left for p in pages for l in p.body], default=0.0);
    for i in range(1, len(pages)) {
        before: Page = pages[i - 1];
        after: Page = pages[i];
        if before.empty or after.empty {
            continue;
        }
        last: Line = before.body[-1];
        first: Line = after.body[0];
        if before.is_heading(last) {
            problems.append(
                f"p{i} ends on the section heading {last.text.strip()!r} with its content on p{i + 1}. Shorten the entry that follows it, or let the heading and its first entry move to the next page together",
            );
            continue;
        }
        tail: list[Line] = [l for l in before.body if l.top >= last.top - SAME_PRINTED_LINE_PT];
        last_x: float | None = printed_text_x(tail);
        if last_x is None {
            if last.left <= doc_left + INDENT_PT < first.left {
                problems.append(
                    f"p{i} ends on a lone list marker whose text continues on p{i + 1} ({first.text.strip()[:60]!r}): a bullet is split across the page break. Shorten the preceding content so the whole item fits on one page",
                );
            }
            continue;
        }
        openers: list[Line] = [
            l
            for l in after.body
            if TEXT_RE.search(l.text) and l.text_x <= doc_left + SET_IN_LIMIT_PT
        ];
        if not openers {
            continue;
        }
        opener: Line = openers[0];
        next_x: float | None = printed_text_x([
            l
            for l in after.body
            if abs(l.top - opener.top) <= SAME_PRINTED_LINE_PT
        ]);
        if next_x is not None and next_x > last_x + INDENT_PT {
            shown: Line = max(
                [l for l in tail if TEXT_RE.search(l.text)],
                key=lambda (l: Line) -> int { len(l.text) },
            );
            problems.append(
                f"p{i} ends on {shown.text.strip()[:60]!r} while the text on p{i + 1} starts further in ({opener.text.strip()[:60]!r}): an entry header is orphaned from its bullets. Add \\needspace before that \\cventry, or shorten it",
            );
        }
    }
    return problems;
}

"""Print each page's measurements and return the layout problems found."""
def `report(path: Path, pages: list[Page]) -> list[str] {
    problems: list[str] = [];
    print(f"{path}: {len(pages)} page(s) (page count is verify_pdf.jac's job, not checked here)");
    for (i, page) in enumerate(pages, 1) {
        if page.empty {
            problems.append(f"p{i} contains no text");
            print(f"  p{i}: EMPTY");
            continue;
        }
        (gap, gap_y) = page.largest_gap();
        share: float = page.bottom_space / page.height;
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
    return problems + find_orphans(pages);
}

def _force_utf8_output {
    for stream in (sys.stdout, sys.stderr) {
        reconfigure: any = getattr(stream, "reconfigure", None);
        if reconfigure {
            reconfigure(encoding="utf-8");
        }
    }
}

def main -> int {
    _force_utf8_output();
    ap: argparse.ArgumentParser = argparse.ArgumentParser(
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
        pages: list[Page] = parse_pdf(args.pdf);
    } except RuntimeError as exc {
        print(f"skipped: {exc}", file=sys.stderr);
        return 2;
    }
    problems: list[str] = `report(args.pdf, pages);
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

with entry:__main__ {
    sys.exit(main());
}

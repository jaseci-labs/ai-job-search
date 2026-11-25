"""Measure a compiled CV or cover letter's page layout, instead of eyeballing it.

The compile-and-inspect loop in `05-cv-templates.md` and the verification checklist in
CLAUDE.md already require the layout properties below. Nothing executes them: they are
checked by looking at the rendered page, which is exactly how they get missed. Each
failure below produces a clean compile, a correct page count, and a PDF that passes
`tools/verify_pdf.jac`:

  orphaned entry      A moderncv \\cventry renders as a tabular, so a job entry is one
                      unbreakable block. When it does not fit, the whole entry moves to
                      the next page - or its header lands at the bottom of one page with
                      the bullets resuming on the next. CLAUDE.md calls this "the most
                      common failure".
  internal hole       The space an ejected entry leaves behind. Observed in the wild at
                      273pt, roughly 19 blank lines, mid-page, on a document whose page
                      count was correct and whose visual read looked fine.
  page ends early     A non-final page that stops well short of the bottom.
  final page thin     A last page mostly empty, which reads as an unfinished document.
  footer collision    Body text pushed into the page-number band, the usual result of
                      rescuing a page with \\enlargethispage or a negative \\vspace.

Page count is deliberately NOT checked here: `tools/verify_pdf.jac --pages` already does
that, and CI runs it. Two implementations of one rule drift.

Geometry comes from Poppler word bounding boxes (`pdftotext -bbox`). Poppler is optional
repo-wide - since #369 `verify_pdf.jac` prefers pypdf and falls back to Poppler - but word
bounding boxes have no pypdf equivalent, so this is the one step that still wants it.
Without it, or with a broken extractor, the check reports `skipped:` and exits 2 rather
than inventing a layout failure. A broken extractor has two distinct causes: no `pdftotext`
on PATH has the `-bbox` flag (Git for Windows ships an xpdf build without it, and the check
skips past it to any Poppler further down PATH), and Poppler 26.0x before 26.05 aborts `-bbox`/`-bbox-layout`/`-htmlmeta` on a PDF
whose Info dictionary carries an empty string in any field - which `hyperref` writes for
every field it does not set, so any `lualatex`/`pdflatex` document built with `hyperref`
and no `\\hypersetup{pdftitle=...}` triggers a real Poppler crashing on a legal PDF (#451).
Line height serves
as a font-size proxy to spot section headings. An orphaned entry header is found by where
each line's TEXT starts, after any list marker merged into it, not by its left edge (see
`find_orphans`).

The thresholds below are calibrated for the stock moderncv (`cv/`) and cover.cls
(`cover_letters/`) geometry. A template registered via `/add-template` may need them
retuned - an article-class page number sitting outside the 90pt footer band, for
instance, is read as body text and turns the space above it into a phantom hole.

Usage:
    neojac run jobsearch -- verify_layout cv/main_acme_ml_engineer.pdf
    neojac run jobsearch -- verify_layout cover_letters/cover_acme_ml_engineer.pdf

Exit codes: 0 clean, 1 layout problem, 2 bad invocation or no usable extractor.

The shipped `cv/main_example.pdf` exits 1 by design: its placeholder page 2 is mostly
empty, which is the thin-final-page failure the checklist asks you to fix before sending.

Tests live in tests/test_verify_layout.py and run against synthetic pages, so the
suite needs neither Poppler nor a compiled PDF.
"""

import builtins;

import operator;

import from __future__ { annotations }

import argparse;

import functools;

import os;

import re;

import shutil;

import subprocess;

import sys;

import from dataclasses { dataclass }

import from pathlib { Path }

glob GAP_LIMIT_PT: any = 100.0;

glob BOTTOM_LIMIT_FRACTION: any = 0.25;

glob LAST_PAGE_THIN_FRACTION: any = 0.35;

glob FOOTER_BAND_PT: any = 90.0;

glob INDENT_PT: any = 8.0;

glob LIST_MARKERS: any;

glob SAME_PRINTED_LINE_PT: any;

glob SET_IN_LIMIT_PT: any;

glob HEADING_HEIGHT_RATIO: any;

glob PAGE_RE: any;

glob WORD_RE: any;

glob TEXT_RE: any;

with entry {
    LIST_MARKERS = frozenset("•‣▪●·");
    SAME_PRINTED_LINE_PT = 3.0;
    SET_IN_LIMIT_PT = 60.0;
    HEADING_HEIGHT_RATIO = 1.25;

    PAGE_RE = re.compile("<page width=\"([\\d.]+)\" height=\"([\\d.]+)\">(.*?)</page>", re.S);
    WORD_RE = re.compile(
        "<word xMin=\"([\\d.]+)\" yMin=\"([\\d.]+)\" xMax=\"[\\d.]+\" yMax=\"([\\d.]+)\">([^<]*)</word>",
    );
    TEXT_RE = re.compile("\\w");
}

@dataclass
class Line {
    has top: float;

    has bottom: float;

    has left: float;

    has height: float;

    has text: str;

    has text_left: float | None = None;

    has text_x: float {
        getter {
            return self.left if self.text_left is None else self.text_left;
        }
    }
}

obj Page {
    has height: any,
        lines: any;

    def init(height: float, lines: list[Line]);

    has body: list[Line] {
        getter {
            cutoff: any = self.height - FOOTER_BAND_PT;
            return [l for l in self.lines if l.top < cutoff];
        }
    }

    has empty: bool {
        getter {
            return not self.body;
        }
    }

    has bottom_space: float {
        getter {
            return self.height - max(l.bottom for l in self.body) if self.body else self.height;
        }
    }

    has left_edge: float {
        getter {
            return min(l.left for l in self.body) if self.body else 0.0;
        }
    }

    has body_median_height: float {
        getter {
            heights: any = sorted(l.height for l in self.body);
            return heights[len(heights) // 2] if heights else 0.0;
        }
    }

    """One line in the bottom band is a page number; two means body text spilled in."""
    has footer_crowded: bool {
        getter {
            band: any = self.height - FOOTER_BAND_PT;
            return operator.gt(len({round(l.top, 1) for l in self.lines if l.top >= band}), 1);
        }
    }

    def is_indented(line: Line) -> bool;

    def is_heading(line: Line) -> bool;

    """Largest top-to-top distance between body lines, and where it starts.

        Measured top-to-top rather than bottom-to-top, so a tall line inflates the gap
        by its own height (a 160pt void under a heading reads as ~174pt). That errs
        toward over-detection, which is the right direction for a check whose job is
        to stop a hole from shipping.
        """
    def largest_gap -> tuple[float, float];

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

"""Find a pdftotext binary that supports Poppler's -bbox flag.

    Git for Windows prepends Git's mingw64\\bin to PATH under Git Bash (used by
    Claude Code), shipping an xpdf pdftotext without -bbox. If a working Poppler
    is installed further down PATH (e.g. MiKTeX, Chocolatey, Scoop), probe each
    candidate with -h and pick the first that advertises -bbox (#655). Falls back
    to the first candidate if none advertises -bbox, so the caller keeps today's
    skip message on failure. Returns None if no pdftotext is found at all.

    Cached at module level to avoid re-probing candidates with subprocesses on
    every parse_pdf call within a process.
    """
@functools.cache
def find_pdftotext -> str | None;

def parse_pdf(path: Path) -> list[Page];

"""xMin of the first word after leading LIST_MARKERS words, if there were any."""
def text_start(words: list[tuple[float, float, float, str]]) -> float | None;

"""Where the text of one printed line starts, from the bbox lines that make it up."""
def printed_text_x(lines: list[Line]) -> float | None;

"""A page ending on an entry header or section heading whose content resumes overleaf.

    Two shapes, both documented failures:
      * the last body line of a page is a section heading (stranded heading)
      * the next page's text starts further in than the text of the page's last printed
        line (an entry header), i.e. the entry was split across the break

    The second compares where the TEXT starts, not where the line starts. A template may
    merge a list marker into the line it labels, which moves the line's left edge but not
    its text: in the #481 repro a bullet's first line starts at x58.9 (the marker), level
    with the entry headers at x59.5, while its text and its continuation start at x72.1.
    Read by left edge, a bullet wrapping across the break looked like a header followed by
    indented text, and a real header followed by such a bullet looked level. On the stock
    CV the outer marker may extract as a line of its own; then the header's text (x70.4)
    counted as indented and a header orphaned from its bullets (x81.3) went unreported.

    Only LIST_MARKERS glyphs are set aside. Where a marker is not among them - the stock
    CV's outer marker extracts as `○` on some font setups and as an emoji on others - the
    line keeps the marker's x, which is exactly what the left-edge rule read. That is how
    a stock `[Degree]` line and its description (both text at x70.4) stay reported when
    that marker merges into the header line (header x59.0), as they were. When the marker
    extracts as its own line, the two are level and nothing tells them from a wrapped
    line without font information, so neither this rule nor the left-edge one reports it.
    """
def find_orphans(pages: list[Page]) -> list[str];

def `report(path: Path, pages: list[Page]) -> list[str];

"""Write UTF-8 whatever the host's default encoding is.

    A piped stdout on Windows defaults to the ANSI code page (cp1252 on most
    Western installs), so printing a company, title or file name outside it
    raised UnicodeEncodeError before the workflow saw any output.
    """
def _force_utf8_output -> None;

def main -> int;

with entry:__main__ {
    sys.exit(main());
}

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

import argparse;
import functools;
import os;
import re;
import shutil;
import subprocess;
import sys;
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

    def postinit;

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

    def is_indented(line: Line) -> bool;
    def is_heading(line: Line) -> bool;

    """Largest top-to-top distance between body lines, and the top it starts at."""
    def largest_gap -> tuple[float, float];
}

"""The first pdftotext on PATH that advertises -bbox, else the first one, else None."""
@functools.cache
def find_pdftotext -> str | None;

def parse_pdf(path: Path) -> list[Page];

"""xMin of the first word after leading LIST_MARKERS words, if there were any."""
def text_start(words: list[tuple[float, float, float, str]]) -> float | None;

"""Where the text of one printed line starts, from the bbox lines that make it up."""
def printed_text_x(lines: list[Line]) -> float | None;

"""Page breaks that strand a section heading, an entry header or a list marker.

An entry header is found by where the TEXT of the lines on either side of the break starts,
not by their left edge: a list marker merged into a line moves its edge but not its text.
"""
def find_orphans(pages: list[Page]) -> list[str];

"""Print each page's measurements and return the layout problems found."""
def `report(path: Path, pages: list[Page]) -> list[str];

def _force_utf8_output -> None;
def main -> int;

with entry:__main__ {
    sys.exit(main());
}

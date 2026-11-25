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

import argparse;
import html;
import json;
import os;
import re;
import sys;
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
def _inside_repo(path: Path) -> bool;

def _fold(text: str) -> str;

def _tag_text(run: str) -> str;

def _selector_text(run: str) -> str;

"""Text without invisible characters, with their counts, the tampering count and what they spelled."""
def clean_text(text: str) -> tuple[str, dict[str, any]];

def _attrs(raw: str) -> dict[str, str];

"""True when a tag's attributes hide it, the style read as a browser reads it."""
def _is_hidden(raw_attrs: str) -> bool;

"""Visible text of a page, with excerpts of its hidden elements and everything removed."""
def clean_html(markup: str) -> tuple[str, dict[str, any]];

"""Up to LINE_MAX characters of `line`, always including position `at`."""
def _excerpt(line: str, at: int) -> str;

def _instruction_at(line: str) -> int | None;

"""Instruction-shaped lines, hidden URLs, visible URL count, mixed-script words."""
def scan(visible: str, hidden: str) -> dict[str, any];

def _phrases(counts: list[int], names: list[tuple[str, str]]) -> list[str];

def verdict(findings: dict[str, any]) -> str;

"""Run the whole gate in mode "html", "text" or "auto": the cleaned text and the findings."""
def guard(raw: str, mode: str) -> tuple[str, dict[str, any]];

def _plain_findings(findings: dict[str, any]) -> str;

def _force_utf8_output -> None;

def _read_input(path: Path | None, mode: str) -> str;

def main(argv: list[str] | None = None) -> int;

with entry:__main__ {
    sys.exit(main());
}

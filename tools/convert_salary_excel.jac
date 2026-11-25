"""Convert an Excel file of company salary data into the JSON that salary_lookup reads.

Usage:
    neojac run jobsearch -- convert_salary_excel <path-to-excel-file>
    neojac run jobsearch -- convert_salary_excel <path-to-excel-file> --source "My Union Stats 2025"
    neojac run jobsearch -- convert_salary_excel <path-to-excel-file> --baseline 100 --baseline-desc "Index 100 = median salary"

The output (salary_data.json) is written to the repository root unless --output is given.

Expected Excel format:
    - A header row with column names (auto-detected within the first ten rows)
    - A "Company" or "Firma" column (required)
    - An optional "City" or "By" column. A combined header such as "Firmanavn og by" /
      "Company and City" (no separate city column) is split on the last comma.
    - Any number of numeric data columns; a count column and an index column of the
      same category are grouped into one category.
"""

import argparse, json, math, os, re, sys;
import from pathlib { Path }

glob COMPANY_PATTERNS: set[str] = {"firma", "company", "virksomhed", "employer", "arbejdsgiver"},
     CITY_PATTERNS: set[str] = {"by", "city", "kommune", "location", "lokation", "sted"},
     COUNT_PATTERNS: set[str] = {"antal", "count", "number", "n", "employees", "medarbejdere"},
     INDEX_PATTERNS: set[str] = {
         "indeks",
         "index",
         "idx",
         "salary",
         "løn",
         "median",
         "average",
         "gennemsnit",
     },
     COMPOUND_PATTERNS: set[str] = {
         "firma",
         "antal",
         "indeks",
         "løn",
         "gennemsnit",
         "medarbejdere",
     },
     ID_PATTERNS: set[str] = {"id", "personnummer"},
     DEFAULT_CATEGORY: str = "all_employees",
     WORD_CHAR: str = "[a-zæøåöäü0-9]";

"""openpyxl, or None when it is not installed; loaded when main runs rather than when the module
is: the pytools program starts every module it holds, and openpyxl takes longer to load than
another tool's whole run."""
def _load_openpyxl -> any {
    try {
        import openpyxl;
        return openpyxl;
    } except ImportError {
        return None;
    }
}

"""A finite number from an Excel cell, including localized strings; ValueError otherwise."""
def parse_numeric_cell(value: any) -> float {
    if isinstance(value, bool) or not isinstance(value, (int, float, str)) {
        raise ValueError("not numeric");
    }
    text: any = value;
    if isinstance(value, str) {
        text = "".join(value.split());
        if not text {
            raise ValueError("not numeric");
        }
        if "," in text and "." in text {
            text = text.replace(".", "").replace(",", ".")
                if text.rfind(",") > text.rfind(".")
                else text.replace(",", "");
        } elif re.fullmatch("[+-]?\\d+[,.]\\d{3}", text) {
            raise ValueError("ambiguous thousands separator");
        } else {
            text = text.replace(",", ".");
        }
    }
    number: float = float(text);
    if not math.isfinite(number) {
        raise ValueError("salary values must be finite");
    }
    return number;
}

"""(company, city) from a combined cell split on its last comma; no usable split leaves city empty."""
def split_combined_company_city(value: str) -> tuple[str, str] {
    (company, _, city) = value.rpartition(",");
    (company, city) = (company.strip(), city.strip());
    return (company, city) if company and city else (value, "");
}

"""Whether a pattern is a whole token of the header, or a substring if it is a compound pattern."""
def header_matches(header: str, patterns: set[str]) -> bool {
    h: str = header.lower().strip();
    tokens: list[str] = re.findall(f"{WORD_CHAR}+", h);
    return any([p in tokens or (p in COMPOUND_PATTERNS and p in h) for p in patterns]);
}

"""The header's category name: the header without its count/index words."""
def strip_type_patterns(header: str, patterns: set[str]) -> str {
    name: str = header.lower();
    for p in patterns {
        name = re.sub(f"(?<!{WORD_CHAR}){re.escape(p)}(?!{WORD_CHAR})", "", name);
        if p in COMPOUND_PATTERNS {
            name = name.replace(p, "");
        }
    }
    return name.strip(" _-");
}

def detect_column_type(header: str) -> str | None {
    if header_matches(header, COUNT_PATTERNS) {
        return "count";
    }
    return "index" if header_matches(header, INDEX_PATTERNS) else None;
}

"""Column of the company or city: an exact header, else a matching one that is not a salary column."""
def metadata_column(headers: list[str], patterns: set[str], taken: int | None = None) -> int
    | None {
    usable: list[tuple[int, str]] = [(i, h) for (i, h) in enumerate(headers) if i != taken];
    exact: list[int] = [i for (i, h) in usable if h.lower().strip() in patterns];
    candidates: list[int] = [i for (i, h) in usable if header_matches(h, patterns)];
    plain: list[int] = [i for i in candidates if detect_column_type(headers[i]) is None];
    ranked: list[int] = exact or plain or candidates;
    return ranked[0] if ranked else None;
}

def cell_at(row: any, col: int | None) -> any {
    return row[col] if col is not None and col < len(row) else None;
}

"""Categories as (name, {field: column}): count/index pairs first, then lone columns."""
def detect_categories(columns: list[tuple[int, str]]) -> list[tuple[str, dict[str, int]]] {
    paired: list[tuple[str, dict[str, int]]] = [];
    lone_counts: list[tuple[str, dict[str, int]]] = [];
    free_indexes: list[tuple[int, str, str]] = [
        (i, h, strip_type_patterns(h, INDEX_PATTERNS))
        for (i, h) in columns
        if detect_column_type(h) == "index"
    ];
    for (col, header) in columns {
        if detect_column_type(header) != "count" {
            continue;
        }
        category: str = strip_type_patterns(header, COUNT_PATTERNS);
        partner: list[tuple[int, str, str]] = [x for x in free_indexes if x[2] == category][:1];
        if partner {
            free_indexes.remove(partner[0]);
            paired.append((
                (category or DEFAULT_CATEGORY).replace(" ", "_").replace("-", "_"),
                {"count": col, "index": partner[0][0]},
            ));
        } else {
            lone_counts.append((header.lower().replace(" ", "_"), {"count": col}));
        }
    }
    lone: list[tuple[int, str]] = [(i, h) for (i, h, _) in free_indexes] + [
        (i, h)
        for (i, h) in columns
        if detect_column_type(h) is None
    ];
    return paired + lone_counts + [(h.lower().replace(" ", "_"), {"index": i}) for (i, h) in lone];
}

"""Company entries of one worksheet; an empty list when it has no table header."""
def parse_sheet(ws: any) -> list[dict[str, any]] {
    top: list[list[str]] = [
        [str(c.value).strip() for c in row if c.value]
        for row in ws.iter_rows(min_row=1, max_row=10, values_only=False)
    ];
    named: list[int] = [
        n
        for (n, texts) in enumerate(top, 1)
        if any([header_matches(t, COMPANY_PATTERNS) for t in texts])
    ];
    backed: list[int] = [
        n
        for n in named
        if any([
            header_matches(t, CITY_PATTERNS | COUNT_PATTERNS | INDEX_PATTERNS)
                and not header_matches(t, COMPANY_PATTERNS)
            for t in top[n - 1]
        ])
    ];
    if not named {
        print(
            f"Warning: Could not find header row in sheet '{ws.title}'. Skipping.", file=sys.stderr
        );
        return [];
    }
    header_row: int = (backed or named)[0];
    headers: list[str] = [
        " ".join(str(c.value).split()) if c.value else ""
        for c in ws[header_row]
    ];
    company_col: int | None = metadata_column(headers, COMPANY_PATTERNS);
    city_col: int | None = metadata_column(headers, CITY_PATTERNS, company_col);
    if company_col is None {
        print(f"Warning: Could not find company column in sheet '{ws.title}'.", file=sys.stderr);
        return [];
    }
    combined: bool = city_col is None and header_matches(headers[company_col], CITY_PATTERNS);
    categories: list[tuple[str, dict[str, int]]] = detect_categories([
        (i, h)
        for (i, h) in enumerate(headers)
        if h and i not in (company_col, city_col) and not header_matches(h, ID_PATTERNS)
    ]);
    if not categories and not backed {
        print(
            f"Warning: Skipping sheet '{ws.title}': no table header found (a company word appears only in text, with no salary columns).",
            file=sys.stderr,
        );
        return [];
    }
    if not categories {
        print(
            f"Warning: No salary data columns detected in sheet '{ws.title}' (only a company/city column was found) - the header row may be wrong, or this sheet has no salary data.",
            file=sys.stderr,
        );
    }
    companies: list[dict[str, any]] = [];
    for row in ws.iter_rows(min_row=header_row + 1, values_only=True) {
        company: str = str(cell_at(row, company_col) or "").strip();
        city: str = str(cell_at(row, city_col) or "").strip();
        if not company {
            continue;
        }
        if combined and not city {
            (company, city) = split_combined_company_city(company);
        }
        found: dict[str, any] = {};
        for (name, cols) in categories {
            values: dict[str, any] = {};
            for (field, col) in cols.items() {
                try {
                    number: float = parse_numeric_cell(cell_at(row, col));
                    values[field] = int(number) if field == "count" else number;
                } except (ValueError, TypeError) {
                    values[field] = None;
                }
            }
            if any([v is not None for v in values.values()]) {
                found[name] = values;
            }
        }
        companies.append({"company": company, "city": city, "categories": found});
    }
    return companies;
}

def _force_utf8_output {
    for stream in (sys.stdout, sys.stderr) {
        if hasattr(stream, "reconfigure") {
            stream.reconfigure(encoding="utf-8");
        }
    }
}

def main {
    _force_utf8_output();
    parser: argparse.ArgumentParser = argparse.ArgumentParser(
        description="Convert salary Excel data to JSON"
    );
    parser.add_argument("excel_file", help="Path to the Excel file with salary data");
    parser.add_argument(
        "--output",
        default=None,
        help="Output JSON file path (default: salary_data.json in repo root)",
    );
    parser.add_argument(
        "--source", default=None, help="Name of the data source (e.g., 'Union Statistics 2025')"
    );
    parser.add_argument(
        "--baseline",
        type=float,
        default=100,
        help="Baseline value for index comparison (default: 100)",
    );
    parser.add_argument(
        "--baseline-desc",
        default=None,
        help="Description of what the baseline means (e.g., 'Index 100 = median salary')",
    );
    args: any = parser.parse_args();
    if not math.isfinite(args.baseline) {
        parser.error("--baseline must be a finite number");
    }
    excel_path: Path = Path(args.excel_file);
    if not excel_path.exists() {
        print(f"Error: File not found: {excel_path}", file=sys.stderr);
        sys.exit(1);
    }
    openpyxl: any = _load_openpyxl();
    if openpyxl is None {
        print("Error: openpyxl is required. Install it with: neojac install", file=sys.stderr);
        sys.exit(1);
    }
    output_path: Path = Path(args.output)
        if args.output
        else Path(os.environ.get("JOBSEARCH_ROOT") or Path(__file__).parent.parent)
            / "salary_data.json";
    print(f"Reading: {excel_path}");
    wb: any = openpyxl.load_workbook(excel_path, read_only=True, data_only=True);
    companies: list[dict[str, any]] = [];
    for ws in wb.worksheets {
        print(f"  Parsing sheet: {ws.title}");
        companies.extend(parse_sheet(ws));
    }
    wb.close();
    if not companies {
        print(
            "Error: No data could be parsed from the Excel file.\nMake sure the Excel file has a header row with a 'Company'/'Firma' column.",
            file=sys.stderr,
        );
        sys.exit(1);
    }
    output: dict[str, any] = {
        "metadata": {
            "source": args.source or excel_path.stem,
            "index_baseline": args.baseline,
            "index_label": "Index",
            "baseline_description": args.baseline_desc or f"Index {args.baseline} = baseline",
        },
        "companies": companies,
    };
    with open(output_path, "w", encoding="utf-8") as f {
        json.dump(output, f, ensure_ascii=False, indent=2);
    }
    print(f"\nDone! Wrote {len(companies)} company entries to {output_path}");
}

with entry:__main__ {
    main();
}

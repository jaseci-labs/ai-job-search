# Performance of the Jac rewrite

How fast this repo's Jac rewrite runs compared with the original Python (`4e021e52f`), what
was changed to speed it up, and where neojac (0.5.1) got in the way.

## How it was measured

- **Three builds, same inputs.** *orig* is the Python checkout at `4e021e52f`, run as
  `.venv/bin/python tools/<tool>.py` (CPython 3.12.11, its own venv: pypdf 7.1.1, openpyxl
  3.1.5, PyYAML 6.0.4). *before* is `neojac-deslop` (`459c2ef`), the rewrite as one cpython
  space, run as `dist/jobsearch/jobsearch <tool>`. *after* is this branch, run as
  `dist/jobsearch-linux-x86_64 <tool>`.
- **Alternated runs, medians.** Every workload runs orig, before, after, orig, before,
  after, … 7 times; the table gives each one's median wall time, including process start.
  The test suite runs 3 alternated rounds of each variant's own command.
- **Same output.** For each workload, the exit status, stdout, stderr and any file written
  are compared with orig's (checkout paths normalised, and argparse's program name, which is
  `job_key.py` in orig, `python3.15 -m tools.job_key` in before and `job_key` in after).
  Every workload matches orig. The one exception, `verify_layout`, is not a change made here:
  its report's text says `verify_pdf.jac's job` where orig says `verify_pdf.py's job`, and
  before says the same thing.
- **Inputs** (made by `/tmp/perfbench/gen.py`, not committed): a `seen_jobs.json` of 20,000
  entries (5.3 MB, with non-ASCII names), a 3,000-row tracker CSV with 400 application
  folders, 3,000 `/rank` results, a 6,000-company `salary_data.json`, a 790 KB posting page,
  a 4,000-row `.xlsx`, and a 7-page PDF from pdflatex.
- **The machine was shared**: Linux x86_64, 20 cores, with other users' work keeping the
  1-minute load average between 13 and 120 during the session. The load at the time of each
  measurement is in the table. Numbers taken under heavy load are noisy, so compare the
  columns of a row (taken together, interleaved) more than rows with each other.

Not measured: `fetch_page`, `robots_check`, `check_upstream_updates` and `upstream_triage`,
which need the network or a git remote. They start like the other native tools.

## Results

Median wall time in ms, process start included; 7 alternated runs each. *Speed-up* is before ÷ after, and *vs orig* is orig ÷ after (above 1 means the Jac is faster than the original).

| Workload | orig (Python) | before (Jac, cpython space) | after (Jac, native) | speed-up | vs orig | same output | load |
|---|---:|---:|---:|---:|---:|:--:|---:|
| start-up: page_decode (no-op run) | 14.5 | 100.6 | 2.0 | 50.3× | 7.25× | yes | 33.6 |
| start-up: job_key --help | 30.8 | 128.2 | 3.4 | 37.7× | 9.06× | yes | 33.6 |
| job_key one key | 29.3 | 114.9 | 2.8 | 41.0× | 10.46× | yes | 33.6 |
| job_key --audit 20k entries | 123.4 | 251.3 | 186.0 | 1.4× | 0.66× | yes | 33.0 |
| rank_state candidates 20k | 203.3 | 380.9 | 260.9 | 1.5× | 0.78× | yes | 32.3 |
| rank_state sweep 20k | 106.1 | 227.9 | 136.8 | 1.7× | 0.78× | yes | 31.7 |
| rank_state apply 3k --dry-run | 275.9 | 439.1 | 348.1 | 1.3× | 0.79× | yes | 31.9 |
| scrape_state history | 101.5 | 226.0 | 134.4 | 1.7× | 0.76× | yes | 32.0 |
| posting_guard --html 790 KB | 427.4 | 739.2 | 490.4 | 1.5× | 0.87× | yes | 31.1 |
| html_report 3k rows | 143.4 | 371.5 | 232.2 | 1.6× | 0.62× | yes | 31.0 |
| salary_lookup search 6k | 241.6 | 502.3 | 300.4 | 1.7× | 0.80× | yes | 30.1 |
| salary_lookup --validate 6k | 44.6 | 142.6 | 62.5 | 2.3× | 0.71× | yes | 30.1 |
| security_guards (repo) | 37.2 | 113.9 | 19.5 | 5.8× | 1.91× | yes | 29.6 |
| install_portal_clis --dry-run | 27.3 | 102.6 | 2.6 | 39.5× | 10.50× | yes | 29.6 |
| check_framework_version (git) | 38.2 | 114.8 | 18.3 | 6.3× | 2.09× | yes | 29.6 |
| verify_layout 7-page PDF | 57.9 | 136.4 | 37.0 | 3.7× | 1.56× | yes¹ | 29.6 |
| lint_skills (repo, PyYAML) | 40.7 | 120.1 | 76.0 | 1.6× | 0.54× | yes | 29.1 |
| verify_pdf 7-page PDF (pypdf) | 145.0 | 244.9 | 210.9 | 1.2× | 0.69× | yes | 28.6 |
| convert_salary_excel 4k rows (openpyxl) | 261.5 | 397.8 | 361.9 | 1.1× | 0.72× | yes | 28.0 |
| **test suite** (`neojac run jobsearch -- test`; orig `unittest discover`) | 26 500 | 73 700 | 15 700 | 4.7× | 1.69× | same results² | 12–27 |

¹ Apart from the rewrite's own wording (`verify_pdf.jac's job`), which *before* has as well.
² All three runs fail the same 8 tests. Those tests check that `lint_skills`/`security_guards` pass on the repository, and they fail on the neojac skill directories installed (git-ignored) in `.agents/skills` and `.claude/skills` of every checkout here. A clean checkout passes them: *before* passed all 416 in one. orig has 1,024 tests and the rewrite 416, because the rewrite merged tests into tables. Rounds: orig 26.5/25.5/29.7 s, before 108.6/72.4/73.7 s, after 15.7/18.5/13.5 s.

In short: every tool except the three that load PyPI packages now starts in 2–4 ms, against 15–35 ms for the original and 100–130 ms for the rewrite as it was. Tools whose run is mostly start-up are 5–15× faster than the original. Data-heavy tools are 1.3–2.0× faster than before but still 1.2–1.6× slower than the original (see below why). The test suite went from 2.8× slower than the original to 1.7× faster.

## What made the difference

1. **The tools are a native space** (`space jobsearch: native { entry cli; }`). Before, the
   app was one cpython space holding the tools *and* the tests. Every run started neojac's
   CPython 3.15 (its stdlib in a zip), marshal-loaded all 83 modules' code (31 ms), and
   imported `unittest` because `cli.jac` did (33 ms). That is about 100 ms per run before any
   tool code, which the test suite paid on each of its hundreds of tool subprocesses. Now
   `cli.jac` is compiled to machine code. It imports each tool inside the `match` case that
   runs it, so a run starts only one tool's module. A tool run starts in 2–4 ms against 16–35
   ms for the original Python. Tools that do little more than start up run 5–15× faster than
   the original.
2. **The three tools that need PyPI packages are a separate cpython app, `pytools`**
   (`lint_skills`: PyYAML; `convert_salary_excel`: openpyxl; `verify_pdf`: pypdf). A native
   program that holds *any* module importing a Python module starts CPython when the program
   starts, even if that module never runs (blocker 1). Keeping them in `jobsearch` would add
   about 50 ms to every tool. `jobsearch` execs `dist/pytools/pytools` for them, and first runs
   `neojac build pytools` if one of its sources is newer than its launcher.
3. **The tests are their own cpython app, `tests`.** `jobsearch test` (CI's command) execs
   `neojac run tests`. Its entry builds `jobsearch` and `pytools`, then runs the suite. The
   suite runs the tools as the native program, as a user does. A single app that runs both
   spaces is not an option: the embedded cpython space is installed when the program starts
   (250 ms) (blocker 2).
4. **posting_guard splits the page once.** `clean_html` took a slice of the page per tag,
   with slices of the tag's attributes in between. Native strings find a character offset
   in a non-ASCII string again from the start after any other string is sliced (blocker 3),
   so the loop was quadratic: 1.4 s natively on the 790 KB page, against 0.46 s on CPython.
   `TAG.split(markup)` gives the same pieces in one pass.
5. **PyPI packages load when the tool runs.** A cpython space starts every module wired into
   its entry when it starts, even one only imported in a function body (blocker 4). So
   `convert_salary_excel`'s module-level `import openpyxl` (80 ms) and `lint_skills`' `import
   yaml` (50 ms) ran for every pytools tool. Each now imports its package in `main`.
6. **salary_lookup compiles its 13 name-stripping patterns once**, not one `re.sub(str, …)`
   per pattern per company, twice per company per search.

To run on the native host, some code changed with no change in behaviour:

- `utf-8-sig` files are read as bytes and decoded (blocker 5). Where the original went
  through text mode with universal newlines, the same newline translation is applied.
- Cached functions use `functools.cache(f)` / `lru_cache(maxsize=1)(f)`, since the decorator
  form is refused (E1490). The tests' `cache_clear()` still works.
- `Path.cwd()` is now `Path(os.getcwd())`.
- `.parent` results are wrapped in `Path(...)`, because they are typed `PurePath` (E1001).
- `bytes.decode(..., errors=...)` on an untyped value passes `errors` positionally (blocker 6).
- `types.NoneType` and `contextlib.suppress` are gone: both are CPython modules, and
  importing either starts CPython.
- JSON integers past 64 bits are read as floats (`parse_int`), so `rank_state` and
  `salary_lookup` still reject `10**400` with their own message instead of an `OverflowError`
  traceback.

## Where the Jac is still slower than the original, and why

- **JSON-heavy workloads** (`job_key --audit`, `rank_state`, `scrape_state history`,
  `html_report`, `salary_lookup` search) are faster than *before* but still 1.2–1.6× the
  original. The time is in the native library, not in this repo's code. Same calls, same
  data, native against CPython 3.15 at moderate load:

  | Call | Native | CPython |
  |---|---|---|
  | `json.loads` of the 5.3 MB state | 106 ms | 98 ms |
  | `json.dumps(…, indent=2)` of it | 110 ms | 35 ms |
  | `json.dumps(…)` compact | 87 ms | 42 ms |
  | 10 scans of a 20k-entry `dict[str, any]` with `.get` | 132 ms | 73 ms |
  | `csv.DictReader` over 3,000 rows | 17 ms | 11 ms |
  | NFKD + `combining` filter over 20k names | 48 ms | 286 ms |

  The tools read JSON into `any` values, so every field access is a dynamic lookup. Typing
  the state as objects would mean rewriting every tool's data model. `json.dumps` with
  `indent` is about 3× CPython's C encoder, and the tools' JSON output has to stay
  byte-identical.
- **The pytools tools** pay for neojac's CPython: the launcher shell script, a 3.15
  interpreter whose stdlib is in a zip, and the `_jac` runtime. That is about 40 ms more than
  plain CPython 3.12 for `lint_skills`. They are faster than before, not faster than the
  original.

## Blockers in neojac 0.5.1

Each has a minimal reproduction; the files are in `/tmp/perfbench/repro`, `exp1`, `exp1b`.

1. **A native program starts CPython when it starts if any of its modules imports a Python
   module, even one that never runs.** neojac's docs say the interpreter starts "the first
   time it imports a Python module", and that a module imported in a function body "starts
   where the import first runs … not when the program starts". `lib.jac` has `import yaml;`
   at its top, and `main.jac` imports it only inside `def run`, which a bare run never calls:

   ```jac
   # main.jac            (archwire: lib as lib ++> main;)
   def run(text: str) -> str { import lib; return lib.parse(text); }
   with entry { if len(sys.argv) > 1 { print(run(sys.argv[1])); } else { print("nothing"); } }
   ```

   A bare run opens `lib/python315.zip` 41 times and takes 49.6 ms. With `lib` importing only
   `json`, it takes 1.3 ms. The same happens with `import importlib`, `contextlib` or `types`.
   So a native program cannot load a PyPI package lazily, and the three PyPI tools had to
   become a separate app. Loading one lazily from a function is refused outright:

   ```text
   r_lazy_py.jac:2:5: error[E5090]: neojac does not support an import here yet
    2 |     import pickle;
   ```

   `importlib.import_module` does work, but `importlib` is itself CPython (see above). Its
   classes can't be used in `except` or `isinstance`:
   `error[E1206]: 'pickle.UnpicklingError' is not an exception class` and
   `error[E1179]: isinstance() takes a class, a builtin type or a tuple of them`.
2. **An app that runs a native space and a cpython space installs the cpython space when the
   program starts.** With `app jobsearch { run jobsearch, tests; }`, `jobsearch job_key
   --help` opened 106 `.jacpyc` files and took 250–290 ms, though it never crosses into the
   space.
3. **Slicing non-ASCII strings is quadratic when two strings are sliced in turn.**

   ```jac
   big: str = "é" * 300000; small: str = "Ørsted"; parts: list[str] = [];
   for i in range(0, 300000, 30) { parts.append(big[i:i + 10]); }                         # 1.7 ms
   for i in range(0, 300000, 30) { parts.append(big[i:i + 10]); parts.append(small[1:3]); } # 2122 ms
   ```

   CPython runs the second loop in 2.6 ms. Native strings appear to keep one character-offset
   cache for the whole program, so slicing `small` evicts `big`'s entry, and each slice of
   `big` scans from its start. Regex group extraction counts as slicing.
4. **In a cpython space, a module wired into the entry starts with the program even when it
   is imported only in a function body** (`@jac/space.json` lists it as eager, with
   `"imported": []`). Only modules a space's patterns name start lazily. The pytools tools
   can't be named by pytools' patterns, because the tests space imports them too and a module
   is in one space.
5. **Native `open()` lacks most codecs**, though `bytes.decode` has them:

   ```text
   print(open("bom.txt", encoding="utf-8-sig").read());
   LookupError: unknown encoding: utf-8-sig          (also utf_8_sig, cp1252; latin-1 and utf-8 work)
   ```

6. **A keyword argument to a builtin method called on an `any` value compiles, then fails at
   run time:**

   ```text
   data: any = b"caf\xc3\xa9"; print(data.decode("utf-8", errors="replace"));
   TypeError: 'bytes.decode' takes no keyword arguments
   ```

7. **The build cache bakes another checkout's paths into a native program.** Copy a project
   to a second directory and build it there. The copy's program reports the first checkout's
   `__file__`
   (`__file__='/tmp/perfbench/exp1/lib.jac'` printed by `/tmp/perfbench/exp1b`'s binary). So
   every `ROOT`/`DATA_FILE` derived from `__file__` points into the other checkout. This is why
   *after* was measured in this checkout, not in a second worktree.
8. **Typing and library gaps met on the way**, each with a workaround above:
   - `Path(...).parent` is typed `PurePath`:
     `error[E1001]: expected Path, found PurePath` on `p: Path = Path("/tmp/a/b.txt").parent;`
   - `error[E1030]: Path has no method 'cwd'`
   - `error[E1490]: decorator 'functools.cache' is not a compile-time function`
   - `error[E5090]: neojac does not support the type 'type' yet` with
     `error[E1179]` for `isinstance(x, allowed)` where `allowed` is a tuple in a variable
   - `int` is 64-bit: `json.loads("1" + "0"*400)` raises
     `OverflowError: int too large to fit in 64 bits`
   - native `json.dumps` and `csv`, and dynamic `dict[str, any]` access, are 1.6–3× CPython's
     C code (the table above)

## Layout after the change

```
space jobsearch: native  { entry cli; }                         app jobsearch  -> dist/jobsearch-<platform>
space pytools:   cpython { entry pycli; }                       app pytools    -> dist/pytools/pytools
space tests:     cpython { entry tests._run; tests | tests.*; } app tests      -> dist/tests/tests
```

`neojac run jobsearch -- <tool>` and `neojac run jobsearch -- test` work as before.

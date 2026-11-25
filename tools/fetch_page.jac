"""GET a page with browser headers: the 403 retry from 09-web-research.md.

WebFetch names itself as a bot, and many corporate and recruiter sites answer it with 403 while
serving a browser. This is the retry, a tool rather than a documented curl command so that the
workflow's pre-approved grant names `neojac run jobsearch -- fetch_page`: a curl grant with a
free tail is also an upload channel, this is not.

  * GET only: the curl argv is fixed and the URL comes after `--`; urllib is used only when
    curl is absent, and has the same shape.
  * http(s) only: any other scheme exits 2 before anything else happens.
  * robots.txt is enforced: robots_check's gate runs before each GET, redirect targets
    included, and no flag skips it.
  * Fetched content never lands in the repo: --out defaults to the system temp directory and a
    path that resolves inside the repo root is refused.
  * Bounded: 45 s, 5 redirects, 10 MB after Content-Encoding is undone, on both paths.

Usage:
  neojac run jobsearch -- fetch_page <url> [--out PATH] [--text] [--max-chars N]

Prints `HTTP <code> size=<bytes> saved=<path>` and exits 0 whatever the HTTP status. With
--text, also prints the tag-stripped page text, capped at --max-chars (default 6000), after a
`--- text ---` line; a body that is not valid UTF-8 is decoded by the charset the page declares.

Exit codes: 0 fetched; 1 refused by robots policy (go to escalation step 4);
2 usage or transport error.
"""

import argparse, gzip, hashlib, html, os, re, shutil, string, subprocess, sys, tempfile, time, zlib;
import from functools { lru_cache }
import from pathlib { Path }
import from urllib.error { HTTPError }
import from urllib.parse { quote, urljoin, urlsplit }
import from urllib.request { HTTPRedirectHandler, Request, build_opener }

glob ROOT: Path = Path(os.environ.get("JOBSEARCH_ROOT") or Path(__file__).resolve().parent.parent),
     ACCEPT: str = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
     ACCEPT_LANGUAGE: str = "en-GB,en;q=0.9",
     TIMEOUT_SECONDS: int = 45,
     MAX_REDIRECTS: int = 5,
     MAX_BYTES: int = 10 * 1024 * 1024,
     REDIRECTS: tuple[int, ...] = (301, 302, 303, 307, 308);

"""Whether the curl on PATH can undo a Content-Encoding."""
@lru_cache(maxsize=1)
def _curl_supports_compressed -> bool {
    try {
        proc: any = subprocess.run(
            ["curl", "--version"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=5,
        );
    } except (OSError, subprocess.SubprocessError) {
        return False;
    }
    features: str = "^Features:.*\\b(?:libz|brotli|zstd)\\b";
    return proc.returncode == 0
        and re.search(features, proc.stdout, re.IGNORECASE | re.MULTILINE) is not None;
}

"""The argv of one GET without automatic redirects, so the next hop can be gated."""
def build_curl_argv(url: str, out: Path, headers: Path, timeout: float) -> list[str] {
    return [
        "curl",
        "-sS",
        "--max-redirs",
        "0",
        "--max-time",
        str(timeout),
        "--max-filesize",
        str(MAX_BYTES),
        *(["--compressed"] if _curl_supports_compressed() else []),
        "-A",
        BROWSER,
        "-H",
        f"Accept: {ACCEPT}",
        "-H",
        f"Accept-Language: {ACCEPT_LANGUAGE}",
        "-D",
        str(headers),
        "-o",
        str(out),
        "-w",
        "%{http_code}",
        "--",
        url,
    ];
}

"""The Location of the final response in a header dump (a proxy may add an earlier one)."""
def _location(header_text: str) -> str | None {
    for block in reversed(re.split("\\r?\\n\\r?\\n", header_text)) {
        if block.startswith("HTTP/") {
            for line in block.splitlines() {
                if line.lower().startswith("location:") {
                    return line.partition(":")[2].strip();
                }
            }
            break;
        }
    }
    return None;
}

"""Status and Location of one GET through curl, the body saved to `out`."""
def fetch_with_curl(url: str, out: Path, timeout: float) -> tuple[int, str | None] {
    (fd, header_name) = tempfile.mkstemp(prefix=".fetch_page_headers.");
    os.close(fd);
    headers: Path = Path(header_name);
    try {
        proc: any = subprocess.run(
            build_curl_argv(url, out, headers, timeout),
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout + 15,
        );
        if proc.returncode != 0 {
            raise RuntimeError(f"curl exit {proc.returncode}: {proc.stderr.strip()}");
        }
        code: int = int(proc.stdout.strip());
        location: str | None = _location(headers.read_text(encoding="iso-8859-1"));
    } finally {
        headers.unlink(missing_ok=True);
    }
    if out.stat().st_size > MAX_BYTES {
        raise RuntimeError(f"response exceeds {MAX_BYTES} bytes after decompression");
    }
    return (code, location);
}

"""Hands a 3xx response back to the caller, which gates the target first."""
class _NoRedirects(HTTPRedirectHandler) {
    def redirect_request(*args: any, **kwargs: any) -> None {
        return None;
    }
}

"""The same GET for machines without curl; gzip and deflate only."""
def fetch_with_urllib(url: str, out: Path, timeout: float) -> tuple[int, str | None] {
    request: any = Request(
        url,
        headers={
            "User-Agent": BROWSER,
            "Accept": ACCEPT,
            "Accept-Language": ACCEPT_LANGUAGE,
            "Accept-Encoding": "gzip, deflate",
        },
    );
    try {
        response: any = build_opener(_NoRedirects()).open(request, timeout=timeout);
    } except HTTPError as exc {
        response = exc;
    }
    with response {
        code: int = response.status if hasattr(response, "status") else response.code;
        location: str | None = response.headers.get("Location");
        if code in REDIRECTS and location {
            return (code, location);
        }
        encoding: str = (response.headers.get("Content-Encoding") or "").lower();
        body: bytes = response.read(MAX_BYTES + 1);
    }
    if len(body) > MAX_BYTES {
        raise RuntimeError(f"response exceeds {MAX_BYTES} bytes");
    }
    if encoding == "gzip" {
        body = gzip.decompress(body);
    } elif encoding == "deflate" {
        try {
            body = zlib.decompress(body);
        } except zlib.error {
            body = zlib.decompress(body, -zlib.MAX_WBITS);
        }
    }
    if len(body) > MAX_BYTES {
        raise RuntimeError(f"response exceeds {MAX_BYTES} bytes after decompression");
    }
    out.write_bytes(body);
    return (code, location);
}

"""Plain text of HTML, capped at `limit`: tags stripped, entities unescaped, whitespace folded.

script/style/noscript/svg/template blocks and comments are dropped, through the end of the
input when the closer is missing, as a browser and posting_guard do.
"""
def strip_tags(markup: str, limit: int) -> str {
    text: str = re.sub("(?s)<!--.*?(?:-->|\\Z)", " ", markup);
    text = re.sub(
        "(?is)<(script|style|noscript|svg|template)\\b[^>]*>.*?(?:</\\1\\s*>|\\Z)", " ", text
    );
    text = html.unescape(re.sub("(?s)<[^>]+>", " ", text));
    text = re.sub("[ \\t\\xa0]+", " ", text);
    return re.sub("\\n\\s*\\n+", "\n", text).strip()[:limit];
}

def _default_out(url: str) -> Path {
    digest: str = hashlib.sha1(url.encode("utf-8")).hexdigest()[:12];
    return Path(tempfile.gettempdir()) / f"fetch_page_{digest}.html";
}

def _inside_repo(path: Path) -> bool {
    probe: Path = Path.cwd() / path.expanduser();
    while not probe.exists() and probe.parent != probe {
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

def main(argv: list[str] | None = None) -> int {
    _force_utf8_output();
    parser: argparse.ArgumentParser = argparse.ArgumentParser(
        prog="fetch_page.jac",
        description="GET a page with browser headers (robots.txt enforced); see module docstring.",
    );
    parser.add_argument("url");
    parser.add_argument(
        "--out",
        type=Path,
        default=None,
        help="where to save the body (default: system temp dir; never inside the repo)",
    );
    parser.add_argument("--text", action="store_true", help="also print the tag-stripped text");
    parser.add_argument(
        "--max-chars", type=int, default=6000, help="cap for --text (default 6000)"
    );
    args: argparse.Namespace = parser.parse_args(argv);

    scheme: str = urlsplit(args.url).scheme.lower();
    if scheme not in ("http", "https") {
        print(f"fetch_page: only http(s) URLs are fetched, got scheme {scheme!r}", file=sys.stderr);
        return 2;
    }
    out: Path = args.out if args.out is not None else _default_out(args.url);
    if _inside_repo(out) {
        print(
            f"fetch_page: refusing to write inside the repo ({out}); fetched content is untrusted and belongs in the session scratchpad or the temp directory",
            file=sys.stderr,
        );
        return 2;
    }

    try {
        current: str = args.url;
        deadline: float | None = None;
        for redirects in range(MAX_REDIRECTS + 1) {
            scheme = urlsplit(current).scheme.lower();
            if scheme not in ("http", "https") {
                raise ValueError(f"redirect target must be http(s), got scheme {scheme!r}");
            }
            (rc, message) = gate(current);
            print(message);
            if rc != 0 {
                print(
                    "fetch_page: refused - robots.txt does not permit this path, so the browser-header retry does not run. Go to escalation step 4: search for the employer's own posting.",
                );
                return 1;
            }
            if deadline is None {
                deadline = time.monotonic() + TIMEOUT_SECONDS;
            }
            remaining: float = deadline - time.monotonic();
            if remaining <= 0 {
                raise TimeoutError("fetch exceeded the time limit");
            }
            out.parent.mkdir(parents=True, exist_ok=True);
            (fd, body_name) = tempfile.mkstemp(
                dir=out.parent, prefix=".fetch_page.", suffix=".tmp"
            );
            os.close(fd);
            body: Path = Path(body_name);
            try {
                fetch: any = fetch_with_curl if shutil.which("curl") else fetch_with_urllib;
                (code, location) = fetch(current, body, remaining);
                if code in REDIRECTS and location {
                    if redirects == MAX_REDIRECTS {
                        raise RuntimeError(f"more than {MAX_REDIRECTS} redirects");
                    }
                    current = urljoin(
                        current, quote(location, encoding="iso-8859-1", safe=string.punctuation)
                    );
                    continue;
                }
                os.replace(body, out);
                status: str = f"HTTP {code} size={out.stat().st_size}";
                break;
            } finally {
                body.unlink(missing_ok=True);
            }
        }
    } except Exception as exc {
        print(f"fetch_page: {type(exc).__name__}: {exc}", file=sys.stderr);
        return 2;
    }

    print(f"{status} saved={out}");
    if args.text {
        print("--- text ---");
        print(strip_tags(decode_page(out.read_bytes()), args.max_chars));
    }
    return 0;
}

with entry:__main__ {
    sys.exit(main());
}

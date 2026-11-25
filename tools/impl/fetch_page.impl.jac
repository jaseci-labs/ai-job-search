impl _curl_supports_compressed -> bool {
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

impl build_curl_argv(url: str, out: Path, headers: Path, timeout: float) -> list[str] {
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

impl _location(header_text: str) -> str | None {
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

impl fetch_with_curl(url: str, out: Path, timeout: float) -> tuple[int, str | None] {
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

impl _NoRedirects.redirect_request(*args: any, **kwargs: any) -> None {
    return None;
}

impl fetch_with_urllib(url: str, out: Path, timeout: float) -> tuple[int, str | None] {
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

impl strip_tags(markup: str, limit: int) -> str {
    text: str = re.sub("(?s)<!--.*?(?:-->|\\Z)", " ", markup);
    text = re.sub(
        "(?is)<(script|style|noscript|svg|template)\\b[^>]*>.*?(?:</\\1\\s*>|\\Z)", " ", text
    );
    text = html.unescape(re.sub("(?s)<[^>]+>", " ", text));
    text = re.sub("[ \\t\\xa0]+", " ", text);
    return re.sub("\\n\\s*\\n+", "\n", text).strip()[:limit];
}

impl _default_out(url: str) -> Path {
    digest: str = hashlib.sha1(url.encode("utf-8")).hexdigest()[:12];
    return Path(tempfile.gettempdir()) / f"fetch_page_{digest}.html";
}

impl _inside_repo(path: Path) -> bool {
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

impl main(argv: list[str] | None = None) -> int {
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

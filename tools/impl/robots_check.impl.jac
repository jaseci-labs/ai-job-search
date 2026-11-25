impl _fetch(url, ua) -> any {
    r: any = subprocess.run(
        [
            "curl",
            "-sS",
            "-L",
            "--proto",
            "=http,https",
            "--proto-redir",
            "=http,https",
            "--max-redirs",
            "5",
            "--max-time",
            "12",
            "-A",
            ua,
            "-H",
            "Accept: text/plain,*/*",
            "-w",
            "\n%{http_code}",
            "--",
            url,
        ],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=20,
    );
    if r.returncode != 0 {
        raise RuntimeError("curl exit %d" % r.returncode);
    }
    body: any;
    _: any;
    code: any;
    (body, _, code) = r.stdout.rpartition("\n") as any;
    return (body, `int(code or 0));
}

impl is_robots_body(text) -> any {
    text = text.removeprefix("﻿");
    lines: any = [raw.split("#", 1)[0].strip() for raw in text.splitlines()];
    if not `any(lines) {
        return True;
    }
    line: any;
    for line in lines {
        line = line.lower();
        if ":" in line
            and line.split(":", 1)[0].strip()
                in ("user-agent", "allow", "disallow", "sitemap", "crawl-delay", "host")
        {
            return True;
        }
    }
    return False;
}

impl has_undecodable_rule(text) -> any {
    for raw in text.removeprefix("﻿").splitlines() {
        line: any = raw.split("#", 1)[0];
        if "�" in line and ":" in line {
            field: any = line.split(":", 1)[0].replace("�", "").strip().lower();
            if field in ("user-agent", "allow", "disallow") {
                return True;
            }
        }
    }
    return False;
}

impl _groups(text) -> any {
    out: any;
    agents: any;
    expect: any;
    (out, agents, expect) = ({}, [], True);
    for raw in text.removeprefix("﻿").splitlines() {
        line: any = raw.split("#", 1)[0].strip();
        if not line or ":" not in line {
            continue;
        }
        field: any;
        _: any;
        value: any;
        (field, _, value) = line.partition(":") as any;
        (field, value) = (field.strip().lower(), value.strip());
        if field == "user-agent" {
            if not expect {
                (agents, expect) = ([], True);
            }
            agents.append(value.lower());
            out.setdefault(value.lower(), []);
        } elif field in ("allow", "disallow") and agents {
            expect = False;
            for a in agents {
                out[a].append((operator.eq(field, "allow"), value));
            }
        }
    }
    return out;
}

impl _match(pattern, path) -> any {
    if pattern == "" {
        return -1;
    }
    pattern = unquote(pattern);
    end_anchor: any = pattern.endswith("$");
    pat: any = re.sub("\\*{2,}", "*", pattern[:-1] if end_anchor else pattern);
    reach: any = [True] + [False] * len(pat);
    j: any;
    c: any;
    for (j, c) in enumerate(pat, 1) {
        if c != "*" {
            break;
        }
        reach[j] = True;
    }
    if reach[-1] and not end_anchor {
        return len(pattern);
    }
    for ch in path {
        step: any = [False] * (len(pat) + 1);
        for (j, c) in enumerate(pat, 1) {
            if c == "*" {
                step[j] = step[j - 1] or reach[j];
            } elif c == ch {
                step[j] = reach[j - 1];
            }
        }
        reach = step;
        if reach[-1] and not end_anchor {
            return len(pattern);
        }
    }
    return len(pattern) if reach[-1] else -1;
}

impl allowed(text, agent, path) -> any {
    g: any = _groups(text);
    rules: any = g.get(agent.lower()) or g.get("*") or [];
    best_len: any;
    best_allow: any;
    (best_len, best_allow) = (-1, True);
    for (is_allow, pat) in rules {
        n: any = _match(pat, path);
        if n > best_len or n == best_len and n >= 0 and not is_allow {
            (best_len, best_allow) = (n, is_allow);
        }
    }
    return True if best_len < 0 else best_allow;
}

impl gate(url) -> any {
    parts: any = urlsplit(url);
    if parts.scheme not in ("http", "https") {
        return (
            1,
            f"UNCONFIRMED (unsupported URL scheme {parts.scheme!r}) - do not retry, go to step 3",
        );
    }
    if not parts.netloc {
        return (1, "UNCONFIRMED (no host in the URL) - do not retry, go to step 3");
    }
    path: any = unquote(parts.path) or "/";
    if parts.query {
        path += "?" + unquote(parts.query);
    }
    robots: any = f"{parts.scheme}://{parts.netloc}/robots.txt";
    body: any;
    last: any;
    (body, last) = (None, "no attempt");
    for ua in ("Claude-User", BROWSER) {
        try {
            text: any;
            code: any;
            (text, code) = _fetch(robots, ua) as any;
        } except Exception as e {
            last = `type(e).__name__;
            continue;
        }
        if code == 404 {
            return (0, "ALLOWED - no robots.txt published");
        }
        if code == 200 {
            if not is_robots_body(text) {
                last = "HTTP 200 but the body is not a robots.txt";
                continue;
            }
            if has_undecodable_rule(text) {
                last = "HTTP 200 but a User-agent/Allow/Disallow line is not valid UTF-8";
                continue;
            }
            body = text;
            break;
        }
        last = "HTTP %d" % code;
    }
    if body is None {
        return (1, "UNCONFIRMED (%s) - do not retry, go to step 3" % last);
    }
    for a in ("Claude-User", "*") {
        if not allowed(body, a, path) {
            return (1, f"DISALLOWED for {a} - do not retry, go to step 3");
        }
    }
    return (0, "ALLOWED - robots.txt permits this path");
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
    if len(sys.argv) != 2 {
        print("usage: jobsearch robots_check <url>", file=sys.stderr);
        return 2;
    }
    result: any = gate(sys.argv[1]);
    print(result[1]);
    return result[0];
}

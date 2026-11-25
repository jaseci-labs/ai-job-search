impl _fetch(url: str, ua: str) -> tuple[str, int] {
    r: any = subprocess.run(
        [*CURL, "-A", ua, "-H", "Accept: text/plain,*/*", "-w", "\n%{http_code}", "--", url],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=20,
    );
    if r.returncode != 0 {
        raise RuntimeError(f"curl exit {r.returncode}");
    }
    (body, _, code) = r.stdout.rpartition("\n");
    return (body, int(code or 0));
}

impl _lines(text: str) -> list[str] {
    return [raw.split("#", 1)[0] for raw in text.removeprefix(BOM).splitlines()];
}

impl is_robots_body(text: str) -> bool {
    lines: list[str] = [line.strip().lower() for line in _lines(text)];
    return not any(lines)
        or any([":" in line and line.split(":", 1)[0].strip() in BODY_FIELDS for line in lines]);
}

impl has_undecodable_rule(text: str) -> bool {
    return any([
        UNDECODABLE in line
            and ":" in line
            and line.split(":", 1)[0].replace(UNDECODABLE, "").strip().lower() in RULE_FIELDS
        for line in _lines(text)
    ]);
}

impl _groups(text: str) -> dict[str, list[tuple[bool, str]]] {
    out: dict[str, list[tuple[bool, str]]] = {};
    agents: list[str] = [];
    in_agents: bool = True;
    for line in _lines(text) {
        if ":" not in line {
            continue;
        }
        (name, _, value) = line.partition(":");
        (name, value) = (name.strip().lower(), value.strip());
        if name == "user-agent" {
            if not in_agents {
                (agents, in_agents) = ([], True);
            }
            agents.append(value.lower());
            out.setdefault(value.lower(), []);
        } elif name in ("allow", "disallow") and agents {
            in_agents = False;
            for agent in agents {
                out[agent].append((name == "allow", value));
            }
        }
    }
    return out;
}

impl _match(pattern: str, path: str) -> int {
    if pattern == "" {
        return -1;
    }
    pattern = unquote(pattern);
    end_anchor: bool = pattern.endswith("$");
    pat: str = re.sub("\\*{2,}", "*", pattern[:-1] if end_anchor else pattern);
    reach: list[bool] = [True] + [False] * len(pat);
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
        step: list[bool] = [False] * (len(pat) + 1);
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

impl allowed(text: str, agent: str, path: str) -> bool {
    groups: dict[str, list[tuple[bool, str]]] = _groups(text);
    (best_len, best_allow) = (-1, True);
    for (is_allow, pat) in groups.get(agent.lower()) or groups.get("*") or [] {
        n: int = _match(pat, path);
        if n > best_len or n == best_len and n >= 0 and not is_allow {
            (best_len, best_allow) = (n, is_allow);
        }
    }
    return best_allow;
}

impl gate(url: str) -> tuple[int, str] {
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
    path: str = unquote(parts.path) or "/";
    if parts.query {
        path += "?" + unquote(parts.query);
    }
    body: str | None = None;
    last: str = "no attempt";
    for ua in (AGENT, BROWSER) {
        try {
            (text, code) = _fetch(f"{parts.scheme}://{parts.netloc}/robots.txt", ua);
        } except Exception as e {
            last = type(e).__name__;
            continue;
        }
        if code == 404 {
            return (0, "ALLOWED - no robots.txt published");
        }
        if code != 200 {
            last = f"HTTP {code}";
        } elif not is_robots_body(text) {
            last = "HTTP 200 but the body is not a robots.txt";
        } elif has_undecodable_rule(text) {
            last = "HTTP 200 but a User-agent/Allow/Disallow line is not valid UTF-8";
        } else {
            body = text;
            break;
        }
    }
    if body is None {
        return (1, f"UNCONFIRMED ({last}) - do not retry, go to step 3");
    }
    for agent in (AGENT, "*") {
        if not allowed(body, agent, path) {
            return (1, f"DISALLOWED for {agent} - do not retry, go to step 3");
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
    (code, message) = gate(sys.argv[1]);
    print(message);
    return code;
}

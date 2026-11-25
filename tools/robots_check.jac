"""Decide whether the browser-header retry in 09-web-research.md may run on a URL.

The retry gets past bot-filtering firewalls on sites whose robots.txt permits access; it never
overrides a site that has said no. Rules (RFC 9309), on the cautious side:
  * longest match wins, and on equal specificity Disallow wins
  * a Disallow for either "*" or "Claude-User" blocks the retry
  * blank lines inside a record do not end it, and one leading byte-order mark is skipped
  * 404 means no published policy, which is permission; so is an empty or comment-only body
  * a 200 whose body is not a robots.txt (an HTML or JSON error page) is unreadable, and so is
    one whose User-agent, Allow or Disallow line holds U+FFFD (a byte that is not valid UTF-8)
  * any failure to read robots.txt leaves permission unconfirmed, and the retry does not happen
  * only an http(s) URL with a host is checked; curl is pinned to http(s) on every redirect

Usage:  neojac run jobsearch -- robots_check <url>
Exit 0 = the retry may proceed. Exit 1 = do not retry; go to escalation step 3.
"""

import re, subprocess, sys;
import from urllib.parse { urlsplit, unquote }

glob BROWSER: str = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36",
     AGENT: str = "Claude-User",
     BOM: str = "﻿",
     UNDECODABLE: str = "�",
     RULE_FIELDS: tuple[str, ...] = ("user-agent", "allow", "disallow"),
     BODY_FIELDS: tuple[str, ...] = (*RULE_FIELDS, "sitemap", "crawl-delay", "host"),
     CURL: list[str] = [
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
     ];

"""Body and HTTP status of a GET through curl, whose --max-time is a hard ceiling."""
def _fetch(url: str, ua: str) -> tuple[str, int] {
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

"""The lines of a robots.txt without their comments, one leading byte-order mark skipped."""
def _lines(text: str) -> list[str] {
    return [raw.split("#", 1)[0] for raw in text.removeprefix(BOM).splitlines()];
}

"""Whether a 200 body is a robots.txt: empty, comments only, or holding a known directive."""
def is_robots_body(text: str) -> bool {
    lines: list[str] = [line.strip().lower() for line in _lines(text)];
    return not any(lines)
        or any([":" in line and line.split(":", 1)[0].strip() in BODY_FIELDS for line in lines]);
}

"""Whether a User-agent, Allow or Disallow line holds U+FFFD, even before the field name."""
def has_undecodable_rule(text: str) -> bool {
    return any([
        UNDECODABLE in line
            and ":" in line
            and line.split(":", 1)[0].replace(UNDECODABLE, "").strip().lower() in RULE_FIELDS
        for line in _lines(text)
    ]);
}

"""user-agent -> [(is_allow, pattern)], tolerating blank lines inside a record."""
def _groups(text: str) -> dict[str, list[tuple[bool, str]]] {
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

"""Length of an RFC 9309 wildcard match, or -1.

The pattern is percent-decoded like the path, and '$' anchors only at its end. Matching is a
table walk in O(len(pattern) * len(path)), never a regex, which a site could make backtrack
exponentially (GHSA-xhqf-8q8x-4jwm).
"""
def _match(pattern: str, path: str) -> int {
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

def allowed(text: str, agent: str, path: str) -> bool {
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

"""Exit code and message for a URL: 0 when its site's robots.txt permits the path."""
def gate(url: str) -> tuple[int, str] {
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

"""Write UTF-8 whatever the host's default encoding is (a piped stdout on Windows is ANSI)."""
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
    if len(sys.argv) != 2 {
        print("usage: jobsearch robots_check <url>", file=sys.stderr);
        return 2;
    }
    (code, message) = gate(sys.argv[1]);
    print(message);
    return code;
}

with entry:__main__ {
    sys.exit(main());
}

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

import re;
import subprocess;
import sys;
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
def _fetch(url: str, ua: str) -> tuple[str, int];

"""The lines of a robots.txt without their comments, one leading byte-order mark skipped."""
def _lines(text: str) -> list[str];

"""Whether a 200 body is a robots.txt: empty, comments only, or holding a known directive."""
def is_robots_body(text: str) -> bool;

"""Whether a User-agent, Allow or Disallow line holds U+FFFD, even before the field name."""
def has_undecodable_rule(text: str) -> bool;

"""user-agent -> [(is_allow, pattern)], tolerating blank lines inside a record."""
def _groups(text: str) -> dict[str, list[tuple[bool, str]]];

"""Length of an RFC 9309 wildcard match, or -1.

The pattern is percent-decoded like the path, and '$' anchors only at its end. Matching is a
table walk in O(len(pattern) * len(path)), never a regex, which a site could make backtrack
exponentially (GHSA-xhqf-8q8x-4jwm).
"""
def _match(pattern: str, path: str) -> int;

def allowed(text: str, agent: str, path: str) -> bool;

"""Exit code and message for a URL: 0 when its site's robots.txt permits the path."""
def gate(url: str) -> tuple[int, str];

"""Write UTF-8 whatever the host's default encoding is (a piped stdout on Windows is ANSI)."""
def _force_utf8_output -> None;

def main -> int;

with entry:__main__ {
    sys.exit(main());
}

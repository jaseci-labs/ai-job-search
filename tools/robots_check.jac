"""Decide whether the browser-header curl retry in 09-web-research.md may run.

The retry exists to get past bot-filtering firewalls on sites whose robots.txt
permits access. It is never used to override a site that has said no.

WebFetch identifies itself as Claude-User and honors robots.txt, so a 403 has
two very different causes: a WAF default on a site whose published policy
allows access, or a site that has actually declined. This tells them apart.

Rules implemented (RFC 9309), deliberately on the cautious side:
  * longest-match wins; on equal specificity Disallow wins
  * a Disallow for either "*" or "Claude-User" blocks the retry
  * blank lines inside a record do not end it (Python's robotparser drops
    rules in that case, which fails open - see tests)
  * one leading UTF-8 byte-order mark is skipped (left in, it hides a first
    "User-agent" line and drops that whole group, which fails open)
  * 404 means no published policy, which is permission
  * a 200 whose body is not a robots.txt (an HTML or JSON error page) is
    unreadable, not permission; an empty body, or one of nothing but
    comments (Rails' default robots.txt), is a valid allow-all
  * any other failure to read robots.txt leaves permission unconfirmed,
    and the retry does not happen - including a User-agent, Allow or
    Disallow line holding U+FFFD, i.e. a byte that is not valid UTF-8
  * only an http or https URL with a host is checked at all; anything else
    is unconfirmed without a request, and curl itself is pinned to http(s)
    on the first hop and on every redirect

Usage:  neojac run jobsearch -- robots_check <url>
Exit 0 = the retry may proceed. Exit 1 = do not retry; go to escalation step 3.
"""

import operator;

import re;
import subprocess;
import sys;

import from urllib.parse { urlsplit, unquote }

glob BROWSER: any = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36";

"""curl, not urllib: some hosts (jobup.ch) hang urllib indefinitely while
    answering curl in under a second, and --max-time is a hard ceiling."""
def _fetch(url, ua) -> any;

"""Does this actually look like a robots.txt?

    A misconfigured host can answer /robots.txt with 200 and an HTML error page.
    That body parses to zero rules, and zero rules read as "allowed" - so a
    soft-200 granted permission that was never given. An empty or whitespace-only
    body IS a valid allow-all under RFC 9309 and stays allowed, and so does a body
    of nothing but comments (Rails' default robots.txt, served by
    job-boards.greenhouse.io): comments carry no rules, so it is the same file.
    Any other non-empty body with no recognised directive is treated as unreadable.

    Accepted on purpose: a plain-text error page made only of '#' lines
    ("# 404 Not Found") reads as allow-all too. RFC 9309 parses it that way,
    no body shape can tell it from a one-comment robots.txt, and a host that
    answers like that has published no policy - the same as a 404, which is
    permission. The soft 200 that can hide a real policy (a firewall or login
    page) is HTML, and stays unreadable.
    """
def is_robots_body(text) -> any;

"""Does a User-agent, Allow or Disallow line hold U+FFFD?

    U+FFFD stands in for a byte that did not decode as UTF-8. A non-conformant
    robots.txt saved in a legacy code page (cp1254, ISO-8859-9) with raw
    non-ASCII bytes in a rule yields a pattern that can never match: the rule
    was silently skipped and the path read as allowed. Such a body is
    unreadable, not permissive. The field is named with U+FFFD removed, so a
    stray byte before "Disallow" cannot hide the line. U+FFFD in a comment or
    in any other field (Sitemap, Crawl-delay, ...) decides nothing and is
    ignored.
    """
def has_undecodable_rule(text) -> any;

"""user-agent -> [(is_allow, pattern)], tolerating blank lines inside a record.

    One leading U+FEFF is skipped, as Google's reference parser does. A file
    saved with a UTF-8 byte-order mark otherwise hid its first field: a leading
    "User-agent: *" went unseen, every rule in its group was dropped for want
    of an agent, and "Disallow: /" read as allow-all.
    """
def _groups(text) -> any;

"""RFC 9309 wildcard match; returns match length or -1.

    The pattern is percent-decoded to match the already-decoded path. Without
    this, "Disallow: /foo%20bar" never matched "/foo bar" and the rule was
    silently skipped - a fail-open on any site that encodes its own rules.
    Under RFC 9309 section 2.2.2, '$' anchors the end of the URL only when
    at the end of the pattern; mid-pattern '$' is matched literally.

    Matching is a table walk in O(len(pattern) * len(path)), never a regex.
    Each '*' used to become '.*', and a non-matching rule with repeated
    wildcard segments ("/*a*a*a...*b$") sent Python's backtracking engine into
    exponential time - minutes at 16 segments - on a file the site controls
    (GHSA-xhqf-8q8x-4jwm). Consecutive '*' match as one, as RFC 9309 implies.
    """
def _match(pattern, path) -> any;

def allowed(text, agent, path) -> any;

def gate(url) -> any;

"""Write UTF-8 whatever the host's default encoding is.

    A piped stdout on Windows defaults to the ANSI code page (cp1252 on most
    Western installs), so printing messages or paths outside it raised
    UnicodeEncodeError before the workflow saw any output.
    """
def _force_utf8_output -> None;

def main -> int;

with entry:__main__ {
    sys.exit(main());
}

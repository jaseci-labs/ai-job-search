"""Shared fork-detection for tests that only apply to the upstream template.

Several guards (placeholder integrity, template placeholders) assert on the
pristine upstream files, so they must skip on personalized forks. In CI the
``GITHUB_REPOSITORY`` variable is authoritative; in a local run it is unset,
so fall back to the checkout's ``origin`` remote instead of assuming
upstream.
"""

import builtins;

import operator;

import os;

import subprocess;

import from pathlib { Path }

glob UPSTREAM: any = "ai-job-search-dev/ai-job-search";

glob REPO: any;

glob _HTTPS_PREFIX: any;

glob _SSH_PREFIX: any;

glob _SSH_URL_PREFIX: any;

with entry {
    REPO = Path(__file__).resolve().parent.parent;

    _HTTPS_PREFIX = "https://github.com/";
    _SSH_PREFIX = "git@github.com:";
    _SSH_URL_PREFIX = "ssh://git@github.com/";
}

"""Whether a git remote URL points at the upstream template repo.

    Matches the https, scp-style ssh and ``ssh://`` forms with an optional
    ``.git`` suffix;
    anything else (a fork URL, some other host) is not upstream.
    """
def _is_upstream_url(url: builtins.str) -> builtins.bool;

"""Whether this checkout is the upstream template rather than a fork.

    ``GITHUB_REPOSITORY`` decides when set (CI). Otherwise the ``origin``
    remote is inspected. When nothing can be determined (git missing,
    timeout, non-zero exit), upstream is assumed: the guards then run
    exactly as they do today.
    """
def is_upstream_checkout -> builtins.bool;

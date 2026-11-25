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

def _is_upstream_url(url: builtins.str) -> builtins.bool;

def is_upstream_checkout -> builtins.bool;

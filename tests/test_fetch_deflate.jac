import http.server;

import contextlib;

import io;

import from pathlib { Path }

import sys;

import from unittest.mock { patch }

import from tempfile { TemporaryDirectory }

import threading;

import unittest;

import zlib;

glob PAGE: any;

with entry {
    PAGE = b"<html><body><h1>Software Engineer</h1><p>Posting details.</p></body></html>";
}

class DeflateBackend(unittest.TestCase) {
    def test_standard_and_legacy_deflate_reach_saved_html_and_text -> any;
}

with entry:__main__ {
    unittest.main();
}

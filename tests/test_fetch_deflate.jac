import contextlib;
import http.server;
import io;
import shutil;
import threading;
import unittest;
import zlib;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest { mock }

glob PAGE: bytes = b"<html><body><h1>Software Engineer</h1><p>Posting details.</p></body></html>";

class _Handler(http.server.BaseHTTPRequestHandler) {
    def do_GET -> None;
    def log_message(*args: any) -> None;
}

class DeflateBackend(unittest.TestCase) {
    def test_standard_and_legacy_deflate_reach_saved_html_and_text;
}

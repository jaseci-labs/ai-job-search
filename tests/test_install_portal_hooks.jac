import base64;

import hashlib;

import http.server;

import io;

import json;

import os;

import from pathlib { Path }

import shutil;

import subprocess;

import sys;

import tarfile;

import from tempfile { TemporaryDirectory }

import threading;

import unittest;

glob ROOT: any;

glob BUN: any;

with entry {
    ROOT = Path(__file__).resolve().parent.parent;
    BUN = os.environ.get("TEST_BUN") or shutil.which("bun");
}

@unittest.skipUnless(BUN, "requires Bun for the offline package-manager integration")
class DependencyHooks(unittest.TestCase) {
    def test_installing_dependency_does_not_execute_its_hook -> any;
}

with entry:__main__ {
    unittest.main();
}

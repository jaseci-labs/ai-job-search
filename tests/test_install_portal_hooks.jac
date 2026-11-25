"""Real Bun install against an offline npm registry: dependency hooks stay off.

The fixture has the same ordinary npm dependency shape as esbuild, whose
postinstall Bun 1.2 runs by default. It writes only a local marker. No public
registry, credentials or lifecycle-script runner is mocked.
"""

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

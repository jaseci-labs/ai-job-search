"""Every local image referenced by README.md must exist in the repo.

A broken header image on the repo landing page is a silent, high-visibility
failure; this guard turns it into a red CI run instead.
"""

import re;

import unittest;

import from pathlib { Path }

glob REPO: any;

glob README: any;

glob IMG_SRC: any;

glob MD_IMG: any;

with entry {
    REPO = Path(__file__).resolve().parent.parent;
    README = REPO / "README.md";

    IMG_SRC = re.compile("<img[^>]+src=\"([^\"]+)\"");
    MD_IMG = re.compile("!\\[[^\\]]*\\]\\(([^)\\s]+)");
}

class ReadmeImageReferences(unittest.TestCase) {
    def _local_refs -> any;

    def test_readme_exists_and_references_at_least_one_local_image -> any;

    def test_all_local_image_references_resolve -> any;
}

with entry:__main__ {
    unittest.main();
}

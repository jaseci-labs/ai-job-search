import re, unittest;

class ReadmeImageReferences(unittest.TestCase) {
    def test_local_image_references_exist_and_resolve {
        text: str = doc("README.md");
        refs: list[str] = [
            ref
            for ref in re.findall("<img[^>]+src=\"([^\"]+)\"", text)
                + re.findall("!\\[[^\\]]*\\]\\(([^)\\s]+)", text)
            if not ref.startswith(("http://", "https://"))
        ];
        self.assertGreaterEqual(len(refs), 1, "README lost its mascot header image");
        for ref in refs {
            with self.subTest(ref=ref) {
                self.assertTrue((REPO / ref).is_file(), f"README references missing file: {ref}");
            }
        }
    }
}

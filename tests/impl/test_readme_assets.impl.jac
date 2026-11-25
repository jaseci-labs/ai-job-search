impl ReadmeImageReferences._local_refs -> any {
    text: any = README.read_text(encoding="utf-8");
    refs: any = IMG_SRC.findall(text) + MD_IMG.findall(text);
    return [r for r in refs if not r.startswith(("http://", "https://"))];
}

impl ReadmeImageReferences.test_readme_exists_and_references_at_least_one_local_image -> any {
    refs: any = self._local_refs();
    self.assertGreaterEqual(len(refs), 1, "README lost its mascot header image");
}

impl ReadmeImageReferences.test_all_local_image_references_resolve -> any {
    for ref in self._local_refs() {
        with self.subTest(ref=ref) {
            self.assertTrue((REPO / ref).is_file(), f"README references missing file: {ref}");
        }
    }
}

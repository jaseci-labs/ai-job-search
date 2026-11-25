impl app_main -> str {
    return str(Path(sys.modules["_jac"].__file__).resolve().parent / "__main__.py");
}

impl tool(name: str) -> list[str] {
    return [sys.executable, app_main(), name];
}

impl rooted(`root: Path | str, env: any = None) -> dict[str, str] {
    return {**(os.environ if env is None else env), "JOBSEARCH_ROOT": str(`root)};
}

impl root_at(fixture: unittest.TestCase, `root: Path | str) -> None {
    patcher = mock.patch.dict(os.environ, {"JOBSEARCH_ROOT": str(`root)});
    patcher.start();
    fixture.addCleanup(patcher.stop);
}

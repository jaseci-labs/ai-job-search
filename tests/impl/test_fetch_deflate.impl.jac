impl _Handler.do_GET -> None {
    body: bytes = b"User-agent: *\nAllow: /\n";
    self.send_response(200);
    if self.path != "/robots.txt" {
        self.server.requests.append((self.path, self.headers.get("Accept-Encoding")));
        encoder: any = zlib.compressobj(
            wbits=-zlib.MAX_WBITS if self.path == "/raw" else zlib.MAX_WBITS
        );
        body = encoder.compress(PAGE) + encoder.flush();
        self.send_header("Content-Encoding", "deflate");
    }
    self.send_header("Content-Length", str(len(body)));
    self.end_headers();
    self.wfile.write(body);
}

impl _Handler.log_message(*args: any) -> None {
    return;
}

impl DeflateBackend.test_standard_and_legacy_deflate_reach_saved_html_and_text {
    server: any = http.server.ThreadingHTTPServer(("127.0.0.1", 0), _Handler);
    server.requests = [];
    thread: threading.Thread = threading.Thread(target=server.serve_forever, daemon=True);
    thread.start();
    self.addCleanup(thread.join);
    self.addCleanup(server.server_close);
    self.addCleanup(server.shutdown);
    with TemporaryDirectory() as directory {
        for path in ("/standard", "/raw") {
            output: Path = Path(directory) / f"{path[1:]}.html";
            argv: list[str] = [
                f"http://127.0.0.1:{server.server_port}{path}",
                "--out",
                str(output),
                "--text",
            ];
            (stdout, stderr) = (io.StringIO(), io.StringIO());
            with self.subTest(encoding=path) {
                with mock.patch.object(
                    shutil, "which", return_value=None
                ), contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr) {
                    code: int = fetch_page.main(argv);
                }
                self.assertEqual(code, 0, stdout.getvalue() + stderr.getvalue());
                self.assertEqual(output.read_bytes(), PAGE);
                self.assertIn("Software Engineer", stdout.getvalue());
                self.assertIn(f"HTTP 200 size={len(PAGE)}", stdout.getvalue());
            }
        }
    }
    self.assertEqual(server.requests, [("/standard", "gzip, deflate"), ("/raw", "gzip, deflate")]);
}

impl DeflateBackend.test_standard_and_legacy_deflate_reach_saved_html_and_text -> any {
    requests: any;
    requests = [];

    class Handler(http.server.BaseHTTPRequestHandler) {
        def do_GET -> any {
            if self.path == "/robots.txt" {
                body: any = b"User-agent: *\nAllow: /\n";
                encoding: any = None;
            } else {
                requests.append((self.path, self.headers.get("Accept-Encoding")));
                encoder: any = zlib.compressobj(
                    wbits=-zlib.MAX_WBITS if self.path == "/raw" else zlib.MAX_WBITS
                );
                body = encoder.compress(PAGE) + encoder.flush();
                encoding = "deflate";
            }
            self.send_response(200);
            if encoding {
                self.send_header("Content-Encoding", encoding);
            }
            self.send_header("Content-Length", `str(len(body)));
            self.end_headers();
            self.wfile.write(body);
        }

        def log_message(*args_) -> any {
            args: any = tuple(args_);
        }
    }

    server: any = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler);
    thread: any = threading.Thread(target=server.serve_forever, daemon=True);
    thread.start();
    try {
        directory: any;
        with TemporaryDirectory() as directory {
            `root: any = Path(directory);
            for path in ("/standard", "/raw") {
                with self.subTest(encoding=path) {
                    output: any = `root / (path[1:] + ".html");
                    stdout: any;
                    stderr: any;
                    (stdout, stderr) = (io.StringIO(), io.StringIO());
                    with patch.object(
                        fetch_page.shutil, "which", return_value=None
                    ), contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr) {
                        code: any = fetch_page.main([
                            f"http://127.0.0.1:{server.server_port}{path}",
                            "--out",
                            `str(output),
                            "--text",
                        ]);
                    }
                    self.assertEqual(code, 0, stdout.getvalue() + stderr.getvalue());
                    self.assertEqual(output.read_bytes(), PAGE);
                    self.assertIn("Software Engineer", stdout.getvalue());
                    self.assertIn(f"HTTP 200 size={len(PAGE)}", stdout.getvalue());
                }
            }
            self.assertEqual(requests, [("/standard", "gzip, deflate"), ("/raw", "gzip, deflate")]);
        }
    } finally {
        server.shutdown();
        server.server_close();
        thread.join();
    }
}

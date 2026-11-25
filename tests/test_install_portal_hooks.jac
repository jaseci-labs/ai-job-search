import base64;
import hashlib, http.server, io, json, os, shutil, subprocess, tarfile, threading, unittest;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }

glob BUN: str | None = os.environ.get("TEST_BUN") or shutil.which("bun");

@unittest.skipUnless(BUN, "requires Bun for the offline package-manager integration")
class DependencyHooks(unittest.TestCase) {
    def test_installing_dependency_does_not_execute_its_hook -> any {
        package: any;
        blob: any;
        package = {
            "name": "esbuild",
            "version": "0.25.0",
            "scripts": {"postinstall": "bun run hook.js"},
        };
        archive: any = io.BytesIO();
        tar: any;
        with tarfile.open(fileobj=archive, mode="w:gz") as tar {
            name: any;
            for (name, data) in {
                "package.json": json.dumps(package).encode(),
                "hook.js": b"await Bun.write(\"hook-ran.txt\", \"ran\");",
            }.items() {
                `entry: any = tarfile.TarInfo("package/" + name);
                `entry.size = len(data);
                tar.addfile(`entry, io.BytesIO(data));
            }
        }
        blob = archive.getvalue();

        class Registry(http.server.BaseHTTPRequestHandler) {
            def do_GET -> any {
                if self.path.endswith(".tgz") {
                    body: any = blob;
                } else {
                    metadata: any = {
                        **package,
                        "dist": {
                            "tarball": f"http://127.0.0.1:{self.server.server_port}/esbuild.tgz",
                            "integrity": "sha512-"
                                + base64.b64encode(hashlib.sha512(blob).digest()).decode(),
                        },
                    };
                    body = json.dumps({
                        "name": "esbuild",
                        "dist-tags": {"latest": "0.25.0"},
                        "versions": {"0.25.0": metadata},
                    }).encode();
                }
                self.send_response(200);
                self.send_header("Content-Length", `str(len(body)));
                self.end_headers();
                self.wfile.write(body);
            }

            def log_message(*args_) -> any {
                args: any = tuple(args_);
            }
        }

        server: any = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Registry);
        thread: any = threading.Thread(target=server.serve_forever, daemon=True);
        thread.start();
        try {
            directory: any;
            with TemporaryDirectory() as directory {
                `root: any = Path(directory);
                tools: any = `root / "tools";
                tools.mkdir();
                cli: any = `root / ".agents/skills/example-search/cli";
                cli.mkdir(parents=True);
                (cli / "package.json").write_text(
                    json.dumps({
                        "name": "example-search",
                        "private": True,
                        "dependencies": {"esbuild": "0.25.0"},
                    }),
                    encoding="utf-8",
                );
                env: any = {
                    "PATH": `str(Path(BUN).absolute().parent) + os.pathsep + os.defpath,
                    "HOME": `str(`root),
                    "TMPDIR": `str(`root),
                    "TEMP": `str(`root),
                    "TMP": `str(`root),
                    "BUN_INSTALL_CACHE_DIR": `str(`root / "cache"),
                    "NPM_CONFIG_REGISTRY": f"http://127.0.0.1:{server.server_port}/",
                };
                if "SYSTEMROOT" in os.environ {
                    env["SYSTEMROOT"] = os.environ["SYSTEMROOT"];
                }
                proc: any = capture(
                    [*tool("install_portal_clis")], env=rooted(`root, env), timeout=30
                );
                self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr);
                dependency: any = cli / "node_modules/esbuild";
                self.assertTrue(
                    (dependency / "hook.js").is_file(), "the dependency was actually installed"
                );
                self.assertFalse(
                    (dependency / "hook-ran.txt").exists(), "the dependency install hook ran"
                );
            }
        } finally {
            server.shutdown();
            server.server_close();
            thread.join();
        }
    }
}

with entry:__main__ {
    unittest.main();
}

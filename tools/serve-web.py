"""Serve only the exported browser preview on localhost (never project sources)."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import argparse


class PreviewHandler(SimpleHTTPRequestHandler):
    extensions_map = {**SimpleHTTPRequestHandler.extensions_map, ".wasm": "application/wasm", ".pck": "application/octet-stream"}

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "same-origin")
        super().end_headers()

    def log_message(self, fmt, *args):
        print("%s %s" % (self.log_date_time_string(), fmt % args), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8080)
    args = parser.parse_args()
    web_root = Path(__file__).resolve().parent.parent / "builds" / "web"
    if not (web_root / "index.html").is_file():
        parser.error("Export the Web Browser Preview preset first (builds/web/index.html is missing).")
    server = ThreadingHTTPServer(("127.0.0.1", args.port), partial(PreviewHandler, directory=str(web_root)))
    print(f"DoodleDrift: http://localhost:{args.port}/", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()

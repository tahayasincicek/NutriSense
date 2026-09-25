"""Synthetic-only provider contract mock; never returns a real health claim."""

from __future__ import annotations

import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class Handler(BaseHTTPRequestHandler):
    server_version = "NutriSenseSyntheticMock/1"

    def _respond(self, status: int, payload: dict) -> None:
        body = json.dumps(payload, separators=(",", ":")).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        if self.path == "/health":
            self._respond(200, {"status": "ready", "synthetic": True})
        else:
            self._respond(404, {"error": "not_found", "synthetic": True})

    def do_POST(self) -> None:
        if self.headers.get("X-Synthetic-Fixture") != "true":
            self._respond(
                403,
                {"error": "synthetic_fixture_header_required", "synthetic": True},
            )
            return
        content_length = min(int(self.headers.get("Content-Length", "0")), 65536)
        self.rfile.read(content_length)
        if self.path == "/vision/analyze":
            self._respond(
                200,
                {
                    "synthetic": True,
                    "fixture_id": "vision-apple-v1",
                    "food_name": "apple",
                    "confidence": 0.91,
                    "is_food": True,
                },
            )
        elif self.path == "/nutrition":
            self._respond(
                200,
                {
                    "synthetic": True,
                    "fixture_id": "nutrition-apple-v1",
                    "canonical_food_id": "food.apple",
                    "available": True,
                    "calories_per_100g": 52,
                },
            )
        else:
            self._respond(404, {"error": "not_found", "synthetic": True})

    def log_message(self, format: str, *args: object) -> None:
        # Avoid request path/header/body logging in the mock.
        return


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", 8090), Handler).serve_forever()

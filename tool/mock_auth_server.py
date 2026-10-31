#!/usr/bin/env python3
"""
Mock Auth Backend — chay thong FastAPI nho cho `/api/auth/*`.

Dung khi backend that tren may chua co router `/api/auth/*`
(server inference-only chi phuc vu `/predict`, `/api/v1/chat/*`,
`/api/v1/plants/search`).

Chay:
    python tool/mock_auth_server.py --port 8000

Tu dong tao user:
    admin / 123456   (ten hien thi: "Admin")
    user1 / 123456   (ten hien thi: "User One")

Chi dung Python stdlib — khong can pip install gi.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import hmac
import json
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

# ── Config ──────────────────────────────────────────────────────────────────

SECRET_KEY = "mock-auth-secret-key-for-local-dev-only"
ACCESS_TTL = 60 * 60 * 24 * 7  # 7 ngay
REFRESH_TTL = 60 * 60 * 24 * 30  # 30 ngay

# username -> (password, display_name)
USERS: dict[str, tuple[str, str]] = {
    "admin": ("123456", "Admin"),
    "user1": ("123456", "User One"),
    "user2": ("123456", "User Two"),
}

# provider_id -> (username, display_name, avatar_url) cho dang nhap xa hoi
SOCIAL_USERS: dict[str, tuple[str, str, str]] = {}

# ── JWT ─────────────────────────────────────────────────────────────────────


def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _b64url_decode(text: str) -> bytes:
    padding = "=" * (-len(text) % 4)
    return base64.urlsafe_b64decode(text + padding)


def make_token(subject: str, kind: str = "access", ttl: int = ACCESS_TTL) -> str:
    header = {"alg": "HS256", "typ": "JWT"}
    payload = {
        "sub": subject,
        "type": kind,
        "iat": int(time.time()),
        "exp": int(time.time()) + ttl,
    }
    segments = [
        _b64url(json.dumps(header, separators=(",", ":")).encode()),
        _b64url(json.dumps(payload, separators=(",", ":")).encode()),
    ]
    signing_input = ".".join(segments).encode("ascii")
    signature = hmac.new(SECRET_KEY.encode(), signing_input, hashlib.sha256).digest()
    segments.append(_b64url(signature))
    return ".".join(segments)


def decode_token(token: str) -> dict | None:
    try:
        header_b64, payload_b64, signature_b64 = token.split(".")
    except ValueError:
        return None
    signing_input = f"{header_b64}.{payload_b64}".encode("ascii")
    expected = hmac.new(SECRET_KEY.encode(), signing_input, hashlib.sha256).digest()
    if not hmac.compare_digest(expected, _b64url_decode(signature_b64)):
        return None
    try:
        payload = json.loads(_b64url_decode(payload_b64))
    except (ValueError, json.JSONDecodeError):
        return None
    if payload.get("exp", 0) < time.time():
        return None
    return payload


def user_profile(username: str) -> dict:
    _, display_name = USERS.get(username, (None, username))
    return {
        "id": str(uuid.uuid5(uuid.NAMESPACE_DNS, username)),
        "username": username,
        "name": display_name,
        "email": f"{username}@example.com",
        "phone_number": "",
        "avatar_url": None,
    }


# ── HTTP handler ────────────────────────────────────────────────────────────


class AuthHandler(BaseHTTPRequestHandler):
    server_version = "MockAuth/1.0"

    def log_message(self, fmt: str, *args) -> None:
        print(f"[mock-auth] {self.address_string()} - {fmt % args}")

    # ── Helpers ──

    def _send(self, status: int, payload: dict) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Access-Control-Allow-Methods", "GET,POST,PATCH,DELETE,OPTIONS")
        self.end_headers()
        self.wfile.write(body)

    def _read_json(self) -> dict:
        length = int(self.headers.get("Content-Length") or 0)
        if length <= 0:
            return {}
        raw = self.rfile.read(length)
        try:
            data = json.loads(raw.decode("utf-8"))
        except (ValueError, UnicodeDecodeError):
            return {}
        return data if isinstance(data, dict) else {}

    def _bearer(self) -> str | None:
        header = self.headers.get("Authorization") or ""
        if header.lower().startswith("bearer "):
            return header[7:].strip()
        return None

    def _require_auth(self) -> dict | None:
        token = self._bearer()
        if not token:
            self._send(401, {"detail": "Not authenticated"})
            return None
        payload = decode_token(token)
        if payload is None:
            self._send(401, {"detail": "Invalid or expired token"})
            return None
        return payload

    def _options(self) -> None:
        self._send(204, {})

    # ── Routes ──

    def do_OPTIONS(self) -> None:  # noqa: N802
        self._options()

    def do_GET(self) -> None:  # noqa: N802
        path = urlparse(self.path).path
        query = parse_qs(urlparse(self.path).query)

        if path == "/api/auth/me":
            payload = self._require_auth()
            if payload is None:
                return
            self._send(200, user_profile(payload["sub"]))
            return

        if path == "/api/auth/check-username":
            username = (query.get("username") or [""])[0].strip()
            available = bool(username) and username not in USERS
            self._send(200, {"username": username, "available": available})
            return

        self._send(404, {"detail": "Not Found"})

    def do_PATCH(self) -> None:  # noqa: N802
        path = urlparse(self.path).path
        if path != "/api/auth/me":
            self._send(404, {"detail": "Not Found"})
            return

        payload = self._require_auth()
        if payload is None:
            return

        body = self._read_json()
        username = payload["sub"]
        new_name = (body.get("username") or body.get("name") or "").strip()
        if new_name:
            _, _ = USERS.get(username, (None, username))
            USERS[username] = (USERS.get(username, ("", ""))[0], new_name)

        profile = user_profile(username)
        self._send(200, profile)

    def do_DELETE(self) -> None:  # noqa: N802
        self._send(200, {"success": True, "message": "Session invalidated"})

    def do_POST(self) -> None:  # noqa: N802
        path = urlparse(self.path).path
        body = self._read_json()

        # ── POST /api/auth/login ──
        if path == "/api/auth/login":
            username = (body.get("username") or body.get("email") or "").strip()
            password = body.get("password") or ""

            if not username or not password:
                self._send(
                    422,
                    {"detail": [{"msg": "username and password are required"}]},
                )
                return

            record = USERS.get(username)
            if record is None:
                # Tu dong dang ky user moi de tien thao thuc.
                USERS[username] = (password, username)
                record = USERS[username]
            elif record[0] != password:
                self._send(401, {"detail": "Sai tên đăng nhập hoặc mật khẩu"})
                return

            self._send(
                200,
                {
                    "access_token": make_token(username, "access"),
                    "refresh_token": make_token(username, "refresh", REFRESH_TTL),
                    "token_type": "bearer",
                    "user": user_profile(username),
                },
            )
            return

        # ── POST /api/auth/register ──
        if path == "/api/auth/register":
            username = (body.get("username") or "").strip()
            password = body.get("password") or ""
            if not username or not password:
                self._send(422, {"detail": [{"msg": "username and password are required"}]})
                return
            if username in USERS:
                self._send(409, {"detail": "Tên đăng nhập đã tồn tại"})
                return
            USERS[username] = (password, username)
            self._send(
                200,
                {
                    "access_token": make_token(username, "access"),
                    "refresh_token": make_token(username, "refresh", REFRESH_TTL),
                    "token_type": "bearer",
                    "user": user_profile(username),
                },
            )
            return

        # ── POST /api/auth/social ──
        if path == "/api/auth/social":
            provider = (body.get("provider") or "").strip().lower()
            provider_id = (body.get("provider_id") or "").strip()
            if provider not in ("google", "facebook") or not provider_id:
                self._send(422, {"detail": [{"msg": "provider and provider_id are required"}]})
                return

            key = f"{provider}:{provider_id}"
            record = SOCIAL_USERS.get(key)
            if record is None:
                display = (body.get("name") or "").strip() or f"{provider.title()} User"
                username = f"{provider}_{provider_id[:12]}"
                USERS[username] = (f"social:{provider_id}", display)
                record = (username, display, body.get("avatar_url") or "")
                SOCIAL_USERS[key] = record

            username = record[0]
            self._send(
                200,
                {
                    "access_token": make_token(username, "access"),
                    "refresh_token": make_token(username, "refresh", REFRESH_TTL),
                    "token_type": "bearer",
                    "user": user_profile(username),
                },
            )
            return

        # ── POST /api/auth/check-phone ──
        if path == "/api/auth/check-phone":
            phone = (body.get("phone_number") or "").strip()
            exists = any(
                f"phone_{phone}" == name for name in USERS
            ) or phone in {"0123456789", "0900000000"}
            self._send(200, {"phone_number": phone, "exists": exists})
            return

        # ── POST /api/auth/refresh ──
        if path == "/api/auth/refresh":
            refresh = (body.get("refresh_token") or "").strip()
            payload = decode_token(refresh) if refresh else None
            if payload is None or payload.get("type") != "refresh":
                self._send(401, {"detail": "Invalid refresh token"})
                return
            self._send(
                200,
                {
                    "access_token": make_token(payload["sub"], "access"),
                    "refresh_token": make_token(payload["sub"], "refresh", REFRESH_TTL),
                    "token_type": "bearer",
                },
            )
            return

        # ── POST /api/auth/logout ──
        if path == "/api/auth/logout":
            self._send(200, {"success": True, "message": "Logged out"})
            return

        # ── POST /api/auth/reset-password ──
        if path == "/api/auth/reset-password":
            new_password = body.get("new_password") or ""
            phone = (body.get("phone_number") or "").strip()
            if not new_password:
                self._send(422, {"detail": [{"msg": "new_password is required"}]})
                return
            for name, (old_password, display) in list(USERS.items()):
                if f"phone_{phone}" == name:
                    USERS[name] = (new_password, display)
            self._send(200, {"success": True, "message": "Đặt lại mật khẩu thành công"})
            return

        self._send(404, {"detail": "Not Found"})


def main() -> None:
    parser = argparse.ArgumentParser(description="Mock auth backend for local dev.")
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8000)
    args = parser.parse_args()

    server = ThreadingHTTPServer((args.host, args.port), AuthHandler)
    print(f"[mock-auth] Listening on http://{args.host}:{args.port}")
    print(f"[mock-auth] Accounts: {', '.join(f'{u}/{p}' for u, (p, _) in USERS.items())}")
    print("[mock-auth] Endpoints: /api/auth/{login,register,social,me,check-username,check-phone,refresh,logout,reset-password}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[mock-auth] Stopped.")
        server.server_close()


if __name__ == "__main__":
    main()

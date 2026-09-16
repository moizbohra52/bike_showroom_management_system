#!/usr/bin/env python3
"""
Local Supabase-compatible gateway.

WHY THIS EXISTS
---------------
The application talks to Supabase, which is three separate services behind one
origin: GoTrue at `/auth/v1`, PostgREST at `/rest/v1`, and Storage at
`/storage/v1`. Running it normally therefore needs either a Supabase cloud
project (an account and API keys) or `supabase start` (Docker Desktop).

When neither is available, this script stands in for that origin so the app can
be run and demonstrated end to end against a real PostgreSQL database with the
project's real migrations, real RLS policies and real RPCs applied. Only the
identity service is emulated; everything that actually matters - the schema, the
row-level security, the accounting transactions - is genuine.

    Flutter  ->  this gateway (:54321)  ->  /auth/v1/*     handled here
                                        ->  /rest/v1/*     PostgREST (:3010)
                                        ->  /storage/v1/*  not implemented

!!! LOCAL DEVELOPMENT ONLY !!!
This is NOT Supabase Auth and must never be used for anything real:

  * passwords are hashed with PBKDF2, not the bcrypt cost Supabase uses;
  * no email is ever sent - password-recovery links are printed to this
    console, which means anyone reading the console can reset any account;
  * no rate limiting, no captcha, no MFA, no email confirmation;
  * the signing secret is a fixed development constant checked into the repo.

It refuses to bind to any address other than the loopback interface for exactly
that reason. Deploy the real thing (see docs/DEPLOYMENT.md) for any environment
that holds data you care about.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import hmac
import http.client
import json
import os
import secrets
import subprocess
import sys
import time
import urllib.parse
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

# --------------------------------------------------------------------------
# Configuration
# --------------------------------------------------------------------------

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
LOCALDEV = os.path.join(PROJECT_ROOT, ".localdev")

PSQL = os.environ.get(
    "BSMS_PSQL", os.path.join(LOCALDEV, "pg", "pgsql", "bin", "psql.exe")
)
PGHOST = os.environ.get("BSMS_PGHOST", "127.0.0.1")
PGPORT = os.environ.get("BSMS_PGPORT", "55432")
PGUSER = os.environ.get("BSMS_PGUSER", "postgres")
PGDATABASE = os.environ.get("BSMS_PGDATABASE", "bsms_verify")

# Shared with PostgREST's `jwt-secret`. Both sides must agree or every
# authenticated request degrades to the anonymous role and RLS hides everything.
JWT_SECRET = os.environ.get(
    "BSMS_JWT_SECRET", "this-is-a-local-test-only-jwt-secret-32chars-min"
)

GATEWAY_PORT = int(os.environ.get("BSMS_GATEWAY_PORT", "54321"))
POSTGREST_HOST = os.environ.get("BSMS_POSTGREST_HOST", "127.0.0.1")
POSTGREST_PORT = int(os.environ.get("BSMS_POSTGREST_PORT", "3010"))

ACCESS_TOKEN_TTL = 3600          # seconds, matches Supabase's default
REFRESH_TOKEN_TTL = 60 * 60 * 24 * 30
PBKDF2_ITERATIONS = 120_000

# --------------------------------------------------------------------------
# JWT (HS256)
# --------------------------------------------------------------------------


def b64url_encode(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode("ascii")


def b64url_decode(value: str) -> bytes:
    padding = "=" * (-len(value) % 4)
    return base64.urlsafe_b64decode(value + padding)


def sign_jwt(payload: dict) -> str:
    header = {"alg": "HS256", "typ": "JWT"}
    signing_input = "{}.{}".format(
        b64url_encode(json.dumps(header, separators=(",", ":")).encode()),
        b64url_encode(json.dumps(payload, separators=(",", ":")).encode()),
    )
    signature = hmac.new(
        JWT_SECRET.encode(), signing_input.encode(), hashlib.sha256
    ).digest()
    return "{}.{}".format(signing_input, b64url_encode(signature))


def verify_jwt(token: str) -> dict | None:
    """Returns the claims when the signature and expiry are both valid."""
    try:
        header_b64, payload_b64, signature_b64 = token.split(".")
    except ValueError:
        return None

    signing_input = "{}.{}".format(header_b64, payload_b64)
    expected = hmac.new(
        JWT_SECRET.encode(), signing_input.encode(), hashlib.sha256
    ).digest()
    if not hmac.compare_digest(expected, b64url_decode(signature_b64)):
        return None

    try:
        claims = json.loads(b64url_decode(payload_b64))
    except (ValueError, json.JSONDecodeError):
        return None

    if "exp" in claims and int(claims["exp"]) < int(time.time()):
        return None
    return claims


def anon_key() -> str:
    """The publishable key handed to the Flutter build.

    A Supabase anon key IS a JWT carrying `role: anon`, signed with the project
    secret. PostgREST reads that claim to decide which database role to assume,
    which is why the key alone grants nothing - RLS still applies.

    Deliberately deterministic: `iat` is a fixed constant rather than the
    current time, so this function returns the same string on every call and on
    every machine. That is what lets the key be written into a checked-in
    `dart_defines/local.json`, which in turn is what makes the IDE's plain Run
    button work without anyone having to paste a freshly minted key first.
    A time-based key would go stale in that file at the next restart and
    produce the "build is not configured" screen all over again.
    """
    issued = 1_700_000_000
    return sign_jwt(
        {
            "iss": "bsms-local-gateway",
            "role": "anon",
            "aud": "authenticated",
            "iat": issued,
            "exp": issued + 60 * 60 * 24 * 365 * 20,
        }
    )


def access_token_for(user: dict, session_id: str) -> str:
    issued = int(time.time())
    return sign_jwt(
        {
            "iss": "bsms-local-gateway",
            "sub": user["id"],
            "aud": "authenticated",
            "role": "authenticated",
            "email": user.get("email") or "",
            "phone": "",
            "session_id": session_id,
            "app_metadata": {"provider": "email", "providers": ["email"]},
            "user_metadata": user.get("raw_user_meta_data") or {},
            "iat": issued,
            "exp": issued + ACCESS_TOKEN_TTL,
        }
    )


# --------------------------------------------------------------------------
# Passwords
# --------------------------------------------------------------------------


def hash_password(password: str) -> str:
    salt = secrets.token_bytes(16)
    derived = hashlib.pbkdf2_hmac(
        "sha256", password.encode(), salt, PBKDF2_ITERATIONS
    )
    return "$pbkdf2-sha256${}${}${}".format(
        PBKDF2_ITERATIONS, b64url_encode(salt), b64url_encode(derived)
    )


def verify_password(password: str, stored: str | None) -> bool:
    if not stored or not stored.startswith("$pbkdf2-sha256$"):
        return False
    try:
        _, _, iterations, salt_b64, hash_b64 = stored.split("$")
        derived = hashlib.pbkdf2_hmac(
            "sha256", password.encode(), b64url_decode(salt_b64), int(iterations)
        )
    except (ValueError, TypeError):
        return False
    return hmac.compare_digest(derived, b64url_decode(hash_b64))


# --------------------------------------------------------------------------
# Database access
#
# psycopg is not installed and this script deliberately has no dependencies
# outside the standard library, so queries go through the bundled `psql`.
# Values are passed as psql variables and interpolated with `:'name'`, which
# applies proper SQL literal quoting - string concatenation into the statement
# would be an injection hole even in a local tool.
# --------------------------------------------------------------------------


class DatabaseError(RuntimeError):
    pass


def sql(statement: str, **params: object) -> str:
    args = [
        PSQL,
        "-h", PGHOST,
        "-p", PGPORT,
        "-U", PGUSER,
        "-d", PGDATABASE,
        "-tAX",
        "-v", "ON_ERROR_STOP=1",
    ]
    for name, value in params.items():
        args += ["-v", "{}={}".format(name, "" if value is None else str(value))]

    # The statement goes in on stdin rather than through `-c`: psql performs
    # variable interpolation (`:'name'`) only when reading a script, so `-c`
    # would pass `:'email'` through to the server verbatim and fail to parse.
    args += ["-f", "-"]

    completed = subprocess.run(
        args,
        input=statement,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if completed.returncode != 0:
        raise DatabaseError((completed.stderr or completed.stdout).strip())
    return (completed.stdout or "").strip()


def query_json(statement: str, **params: object) -> list:
    """Runs a SELECT and returns its rows as a list of dicts."""
    wrapped = (
        "select coalesce(json_agg(row_to_json(q)), '[]'::json) "
        "from ( {} ) q".format(statement.rstrip().rstrip(";"))
    )
    return json.loads(query_scalar(wrapped, **params) or "[]")


def query_scalar(statement: str, **params: object) -> str:
    return sql(statement, **params)


def find_user_by_email(email: str) -> dict | None:
    rows = query_json(
        "select id::text, email, encrypted_password, "
        "coalesce(raw_user_meta_data, '{}'::jsonb) as raw_user_meta_data, "
        "created_at, updated_at, email_confirmed_at, last_sign_in_at "
        "from auth.users where lower(email) = lower(:'email')",
        email=email,
    )
    return rows[0] if rows else None


def find_user_by_id(user_id: str) -> dict | None:
    rows = query_json(
        "select id::text, email, encrypted_password, "
        "coalesce(raw_user_meta_data, '{}'::jsonb) as raw_user_meta_data, "
        "created_at, updated_at, email_confirmed_at, last_sign_in_at "
        "from auth.users where id = :'id'::uuid",
        id=user_id,
    )
    return rows[0] if rows else None


def ensure_schema() -> None:
    """Adds the auth.users columns GoTrue exposes but the SQL test shim omits,
    plus the refresh-token store this gateway needs.

    On a real Supabase project all of this is managed by the platform; here the
    table comes from `supabase/tests/00_supabase_shim.sql`, which only models
    the columns the migrations themselves reference.
    """
    sql(
        """
        alter table auth.users
          add column if not exists updated_at timestamptz default now(),
          add column if not exists email_confirmed_at timestamptz,
          add column if not exists last_sign_in_at timestamptz,
          add column if not exists raw_app_meta_data jsonb default '{}'::jsonb;

        create table if not exists auth.local_refresh_tokens (
          token       text primary key,
          user_id     uuid not null references auth.users(id) on delete cascade,
          session_id  uuid not null,
          expires_at  timestamptz not null,
          revoked     boolean not null default false,
          created_at  timestamptz not null default now()
        );

        create index if not exists local_refresh_tokens_user_idx
          on auth.local_refresh_tokens (user_id);
        """
    )


# --------------------------------------------------------------------------
# GoTrue response shapes
# --------------------------------------------------------------------------


def user_payload(user: dict) -> dict:
    created = user.get("created_at") or ""
    return {
        "id": user["id"],
        "aud": "authenticated",
        "role": "authenticated",
        "email": user.get("email"),
        "phone": "",
        "email_confirmed_at": user.get("email_confirmed_at") or created,
        "confirmed_at": user.get("email_confirmed_at") or created,
        "last_sign_in_at": user.get("last_sign_in_at") or created,
        "app_metadata": {"provider": "email", "providers": ["email"]},
        "user_metadata": user.get("raw_user_meta_data") or {},
        "identities": [],
        "created_at": created,
        "updated_at": user.get("updated_at") or created,
        "is_anonymous": False,
    }


def issue_session(user: dict) -> dict:
    session_id = str(uuid.uuid4())
    refresh_token = secrets.token_urlsafe(32)

    sql(
        "insert into auth.local_refresh_tokens "
        "(token, user_id, session_id, expires_at) values "
        "(:'token', :'user_id'::uuid, :'session_id'::uuid, "
        "now() + make_interval(secs => :ttl));",
        token=refresh_token,
        user_id=user["id"],
        session_id=session_id,
        ttl=REFRESH_TOKEN_TTL,
    )
    sql(
        "update auth.users set last_sign_in_at = now() where id = :'id'::uuid;",
        id=user["id"],
    )

    return {
        "access_token": access_token_for(user, session_id),
        "token_type": "bearer",
        "expires_in": ACCESS_TOKEN_TTL,
        "expires_at": int(time.time()) + ACCESS_TOKEN_TTL,
        "refresh_token": refresh_token,
        "user": user_payload(user),
    }


# --------------------------------------------------------------------------
# HTTP handler
# --------------------------------------------------------------------------

CORS_HEADERS = {
    "Access-Control-Allow-Methods": "GET, POST, PUT, PATCH, DELETE, OPTIONS, HEAD",
    "Access-Control-Allow-Headers": (
        "authorization, x-client-info, apikey, content-type, prefer, range, "
        "accept, accept-profile, content-profile, x-upsert, "
        "x-supabase-api-version, x-region"
    ),
    "Access-Control-Expose-Headers": (
        "content-range, content-location, x-supabase-api-version, "
        "content-profile, range-unit"
    ),
    "Access-Control-Max-Age": "86400",
}


class GatewayHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "bsms-local-gateway"

    # -- plumbing ----------------------------------------------------------

    def log_message(self, fmt: str, *args: object) -> None:
        sys.stderr.write(
            "  {} {}\n".format(time.strftime("%H:%M:%S"), fmt % args)
        )

    def _cors(self) -> None:
        origin = self.headers.get("Origin")
        self.send_header("Access-Control-Allow-Origin", origin or "*")
        self.send_header("Vary", "Origin")
        for header, value in CORS_HEADERS.items():
            self.send_header(header, value)

    def _send_json(self, status: int, body: dict | list) -> None:
        raw = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(raw)))
        self._cors()
        self.end_headers()
        self.wfile.write(raw)

    def _error(
        self,
        status: int,
        code: str,
        message: str,
    ) -> None:
        self._send_json(
            status,
            {
                "code": status,
                "error_code": code,
                "error": code,
                "error_description": message,
                "msg": message,
                "message": message,
            },
        )

    def _body(self) -> dict:
        length = int(self.headers.get("Content-Length") or 0)
        if length == 0:
            return {}
        try:
            return json.loads(self.rfile.read(length) or b"{}")
        except json.JSONDecodeError:
            return {}

    def _bearer_claims(self) -> dict | None:
        header = self.headers.get("Authorization") or ""
        if not header.lower().startswith("bearer "):
            return None
        return verify_jwt(header[7:].strip())

    # -- verbs -------------------------------------------------------------

    def do_OPTIONS(self) -> None:          # noqa: N802 - http.server API
        self.send_response(204)
        self.send_header("Content-Length", "0")
        self._cors()
        self.end_headers()

    def do_GET(self) -> None:              # noqa: N802
        self._dispatch("GET")

    def do_POST(self) -> None:             # noqa: N802
        self._dispatch("POST")

    def do_PUT(self) -> None:              # noqa: N802
        self._dispatch("PUT")

    def do_PATCH(self) -> None:            # noqa: N802
        self._dispatch("PATCH")

    def do_DELETE(self) -> None:           # noqa: N802
        self._dispatch("DELETE")

    def do_HEAD(self) -> None:             # noqa: N802
        self._dispatch("HEAD")

    def _dispatch(self, method: str) -> None:
        parsed = urllib.parse.urlsplit(self.path)
        path = parsed.path

        try:
            if path in ("/", "/health"):
                self._send_json(200, {"status": "ok", "service": self.server_version})
            elif path.startswith("/auth/v1"):
                self._handle_auth(method, path[len("/auth/v1"):], parsed.query)
            elif path.startswith("/rest/v1"):
                self._proxy_rest(method, path[len("/rest/v1"):], parsed.query)
            elif path.startswith("/storage/v1"):
                self._error(
                    501,
                    "not_implemented",
                    "Storage is not emulated by the local gateway. File upload "
                    "and download need a real Supabase project.",
                )
            elif path.startswith("/realtime/v1"):
                self._error(
                    501,
                    "not_implemented",
                    "Realtime is not emulated by the local gateway. Run with "
                    "--dart-define=ENABLE_REALTIME=false.",
                )
            else:
                self._error(404, "not_found", "No route for {}".format(path))
        except DatabaseError as error:
            self._error(500, "database_error", str(error))
        except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
            # The caller went away mid-response: a hot reload, a cancelled
            # fetch, a curl timeout. Nothing to report and nothing to send.
            pass
        except Exception as error:                      # noqa: BLE001
            self._error(500, "gateway_error", repr(error))

    # -- auth --------------------------------------------------------------

    def _handle_auth(self, method: str, route: str, query: str) -> None:
        if route in ("/health", "/"):
            self._send_json(200, {"name": "GoTrue", "version": "local-shim"})
            return

        if route == "/settings" and method == "GET":
            self._send_json(
                200,
                {
                    "external": {"email": True, "phone": False},
                    "disable_signup": False,
                    "mailer_autoconfirm": True,
                    "phone_autoconfirm": False,
                    "sms_provider": "",
                },
            )
            return

        if route == "/.well-known/jwks.json" and method == "GET":
            # Empty set: the SDK falls back to asking the server to verify,
            # which is what we want for a symmetric HS256 secret.
            self._send_json(200, {"keys": []})
            return

        if route == "/token" and method == "POST":
            self._handle_token(query)
            return

        if route == "/signup" and method == "POST":
            self._handle_signup()
            return

        if route == "/user" and method == "GET":
            self._handle_get_user()
            return

        if route == "/user" and method in ("PUT", "PATCH"):
            self._handle_update_user()
            return

        if route == "/logout" and method == "POST":
            self._handle_logout()
            return

        if route == "/recover" and method == "POST":
            self._handle_recover()
            return

        self._error(
            404,
            "not_implemented",
            "The local gateway does not implement {} {}. Only email/password "
            "sign-in, refresh, sign-out, signup, user update and recovery are "
            "emulated.".format(method, route),
        )

    def _handle_token(self, query: str) -> None:
        grant = urllib.parse.parse_qs(query).get("grant_type", ["password"])[0]
        body = self._body()

        if grant == "password":
            email = (body.get("email") or "").strip()
            password = body.get("password") or ""
            if not email or not password:
                self._error(
                    400, "validation_failed", "Email and password are required."
                )
                return

            user = find_user_by_email(email)
            # Same response whether the account is absent or the password is
            # wrong, so this cannot be used to enumerate accounts.
            if user is None or not verify_password(password, user.get("encrypted_password")):
                self._error(
                    400, "invalid_credentials", "Invalid login credentials"
                )
                return

            self._send_json(200, issue_session(user))
            return

        if grant == "refresh_token":
            token = body.get("refresh_token") or ""
            rows = query_json(
                "select t.user_id::text as user_id from auth.local_refresh_tokens t "
                "where t.token = :'token' and t.revoked = false "
                "and t.expires_at > now()",
                token=token,
            )
            if not rows:
                self._error(
                    400, "refresh_token_not_found", "Invalid Refresh Token"
                )
                return

            # Rotate: a refresh token is single-use, so a stolen one is only
            # good until the legitimate client next refreshes.
            sql(
                "update auth.local_refresh_tokens set revoked = true "
                "where token = :'token';",
                token=token,
            )
            user = find_user_by_id(rows[0]["user_id"])
            if user is None:
                self._error(400, "user_not_found", "User not found")
                return
            self._send_json(200, issue_session(user))
            return

        self._error(
            400,
            "unsupported_grant_type",
            "The local gateway supports grant_type=password and "
            "grant_type=refresh_token only.",
        )

    def _handle_signup(self) -> None:
        body = self._body()
        email = (body.get("email") or "").strip().lower()
        password = body.get("password") or ""
        metadata = body.get("data") or {}

        if not email or not password:
            self._error(400, "validation_failed", "Email and password are required.")
            return
        if len(password) < 6:
            self._error(422, "weak_password", "Password should be at least 6 characters.")
            return
        if find_user_by_email(email) is not None:
            self._error(422, "user_already_exists", "User already registered")
            return

        user_id = str(uuid.uuid4())
        sql(
            "insert into auth.users "
            "(id, email, encrypted_password, raw_user_meta_data, "
            " email_confirmed_at) "
            "values (:'id'::uuid, :'email', :'pw', :'meta'::jsonb, now());",
            id=user_id,
            email=email,
            pw=hash_password(password),
            meta=json.dumps(metadata),
        )

        user = find_user_by_id(user_id)
        self._send_json(200, issue_session(user))

    def _handle_get_user(self) -> None:
        claims = self._bearer_claims()
        if not claims or not claims.get("sub"):
            self._error(401, "bad_jwt", "Invalid or expired token")
            return
        user = find_user_by_id(claims["sub"])
        if user is None:
            self._error(404, "user_not_found", "User not found")
            return
        self._send_json(200, user_payload(user))

    def _handle_update_user(self) -> None:
        claims = self._bearer_claims()
        if not claims or not claims.get("sub"):
            self._error(401, "bad_jwt", "Invalid or expired token")
            return

        body = self._body()
        user_id = claims["sub"]

        if body.get("password"):
            if len(body["password"]) < 6:
                self._error(
                    422, "weak_password", "Password should be at least 6 characters."
                )
                return
            sql(
                "update auth.users set encrypted_password = :'pw', "
                "updated_at = now() where id = :'id'::uuid;",
                pw=hash_password(body["password"]),
                id=user_id,
            )

        if body.get("email"):
            sql(
                "update auth.users set email = lower(:'email'), "
                "email_confirmed_at = now(), updated_at = now() "
                "where id = :'id'::uuid;",
                email=body["email"],
                id=user_id,
            )

        if isinstance(body.get("data"), dict):
            sql(
                "update auth.users set raw_user_meta_data = "
                "coalesce(raw_user_meta_data, '{}'::jsonb) || :'meta'::jsonb, "
                "updated_at = now() where id = :'id'::uuid;",
                meta=json.dumps(body["data"]),
                id=user_id,
            )

        user = find_user_by_id(user_id)
        self._send_json(200, user_payload(user))

    def _handle_logout(self) -> None:
        claims = self._bearer_claims()
        if claims and claims.get("session_id"):
            sql(
                "update auth.local_refresh_tokens set revoked = true "
                "where session_id = :'sid'::uuid;",
                sid=claims["session_id"],
            )
        self.send_response(204)
        self.send_header("Content-Length", "0")
        self._cors()
        self.end_headers()

    def _handle_recover(self) -> None:
        body = self._body()
        email = (body.get("email") or "").strip()
        user = find_user_by_email(email)

        # Always 200, regardless of whether the address exists: a different
        # answer would leak which addresses have accounts.
        if user is not None:
            print(
                "\n  [recover] No mail is sent locally. Reset the password "
                "directly instead:\n"
                "    python tools/local_backend/gateway.py set-password "
                "{} <new-password>\n".format(user["email"]),
                flush=True,
            )
        self._send_json(200, {})

    # -- REST proxy --------------------------------------------------------

    def _proxy_rest(self, method: str, route: str, query: str) -> None:
        """Forwards to PostgREST.

        The prefix has to be stripped because PostgREST serves tables at the
        root (`/showrooms`), while the Supabase SDK hardcodes `/rest/v1`
        in front of every path.
        """
        target = route or "/"
        if query:
            target = "{}?{}".format(target, query)

        length = int(self.headers.get("Content-Length") or 0)
        payload = self.rfile.read(length) if length else None

        connection = http.client.HTTPConnection(
            POSTGREST_HOST, POSTGREST_PORT, timeout=30
        )
        forwarded = {
            name: value
            for name, value in self.headers.items()
            if name.lower()
            not in ("host", "connection", "content-length", "accept-encoding")
        }
        forwarded["Accept-Encoding"] = "identity"

        try:
            connection.request(method, target, body=payload, headers=forwarded)
            response = connection.getresponse()
            data = response.read()
        except (ConnectionRefusedError, OSError) as error:
            self._error(
                502,
                "postgrest_unreachable",
                "PostgREST is not answering on {}:{} ({}). Start the backend "
                "with tools/local_backend/start.ps1.".format(
                    POSTGREST_HOST, POSTGREST_PORT, error
                ),
            )
            return
        finally:
            connection.close()

        self.send_response(response.status)
        for name, value in response.getheaders():
            if name.lower() in (
                "transfer-encoding",
                "connection",
                "content-length",
                "access-control-allow-origin",
                "access-control-allow-methods",
                "access-control-allow-headers",
                "access-control-expose-headers",
            ):
                continue
            self.send_header(name, value)
        self.send_header("Content-Length", str(len(data)))
        self._cors()
        self.end_headers()
        if method != "HEAD":
            self.wfile.write(data)


class _QuietThreadingHTTPServer(ThreadingHTTPServer):
    """Suppresses the traceback a dropped connection would otherwise print.

    A browser cancelling an in-flight request — which Flutter's hot reload
    does constantly — reaches the base server as a ConnectionResetError after
    the handler has already returned, and it prints a full traceback to the
    console. This console is the one place a developer watches sign-in and
    REST traffic scroll past, so a wall of tracebacks for a non-event makes
    the real errors harder to spot.
    """

    def handle_error(self, request: object, client_address: object) -> None:
        error = sys.exc_info()[1]
        if isinstance(
            error,
            (BrokenPipeError, ConnectionResetError, ConnectionAbortedError),
        ):
            return
        super().handle_error(request, client_address)  # type: ignore[arg-type]


# --------------------------------------------------------------------------
# Commands
# --------------------------------------------------------------------------


def command_serve(_: argparse.Namespace) -> int:
    ensure_schema()

    print("")
    print("  Local Supabase-compatible gateway")
    print("  " + "-" * 60)
    print("  LOCAL DEVELOPMENT ONLY - emulated auth, no email, no rate limits.")
    print("")
    print("  Listening   http://127.0.0.1:{}".format(GATEWAY_PORT))
    print("  Database    {}@{}:{}/{}".format(PGUSER, PGHOST, PGPORT, PGDATABASE))
    print("  PostgREST   http://{}:{}".format(POSTGREST_HOST, POSTGREST_PORT))
    print("")
    print("  Run the app with:")
    print("")
    print("    flutter run -d chrome "
          "--dart-define-from-file=dart_defines/local.json")
    print("")
    print("  or press F5 in VS Code and pick 'Web - Chrome (local backend)'.")
    print("")
    print("  The backend values live in dart_defines/local.json. A build that")
    print("  omits them stops on the 'build is not configured' screen - the")
    print("  IDE's bare Run button does exactly that.")
    print("")

    # Loopback only. This service has no real authentication hardening and
    # binding it to a routable address would expose every account on it.
    server = _QuietThreadingHTTPServer(
        ("127.0.0.1", GATEWAY_PORT), GatewayHandler
    )
    server.daemon_threads = True
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n  Stopped.")
    return 0


def command_create_user(args: argparse.Namespace) -> int:
    ensure_schema()
    email = args.email.strip().lower()

    if find_user_by_email(email) is not None:
        print("  A user with {} already exists.".format(email))
        return 1

    user_id = str(uuid.uuid4())
    sql(
        "insert into auth.users "
        "(id, email, encrypted_password, raw_user_meta_data, email_confirmed_at) "
        "values (:'id'::uuid, :'email', :'pw', :'meta'::jsonb, now());",
        id=user_id,
        email=email,
        pw=hash_password(args.password),
        meta=json.dumps({"name": args.name} if args.name else {}),
    )
    print("  Created auth user {} ({})".format(email, user_id))

    # The `on_auth_user_created` trigger has created a bare profile with no
    # role and no showroom - by design (see 015_auth_triggers.sql). Promoting
    # is a separate, deliberate step.
    if args.super_admin:
        result = query_scalar(
            "select public.bootstrap_super_admin(:'email')::text;", email=email
        )
        print("  bootstrap_super_admin -> {}".format(result))

    return 0


def command_set_password(args: argparse.Namespace) -> int:
    ensure_schema()
    user = find_user_by_email(args.email)
    if user is None:
        print("  No user with {}".format(args.email))
        return 1
    sql(
        "update auth.users set encrypted_password = :'pw', updated_at = now() "
        "where id = :'id'::uuid;",
        pw=hash_password(args.password),
        id=user["id"],
    )
    print("  Password updated for {}".format(user["email"]))
    return 0


def command_print_keys(_: argparse.Namespace) -> int:
    print(anon_key())
    return 0


def command_list_users(_: argparse.Namespace) -> int:
    rows = query_json(
        """
        select u.email,
               coalesce(p.name, '-')                      as profile,
               coalesce(p.status, '-')                    as status,
               coalesce(string_agg(distinct r.name, ', '), '(no role)') as roles,
               coalesce(s.name, '(no showroom)')          as showroom
        from auth.users u
        left join public.users p    on p.auth_user_id = u.id
        left join public.user_roles ur on ur.user_id = p.id
        left join public.roles r    on r.id = ur.role_id
        left join public.showrooms s on s.id = p.showroom_id
        group by u.email, p.name, p.status, s.name
        order by u.email
        """
    )
    if not rows:
        print("  No users.")
        return 0
    for row in rows:
        print(
            "  {:<32} {:<18} {:<10} {:<24} {}".format(
                row["email"], row["profile"], row["status"],
                row["roles"], row["showroom"],
            )
        )
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Local Supabase-compatible gateway (development only)."
    )
    subparsers = parser.add_subparsers(dest="command")

    serve = subparsers.add_parser("serve", help="Run the gateway.")
    serve.set_defaults(handler=command_serve)

    create = subparsers.add_parser("create-user", help="Create a local account.")
    create.add_argument("email")
    create.add_argument("password")
    create.add_argument("--name", default=None)
    create.add_argument(
        "--super-admin",
        action="store_true",
        help="Also run bootstrap_super_admin() on the new account.",
    )
    create.set_defaults(handler=command_create_user)

    reset = subparsers.add_parser("set-password", help="Change a password.")
    reset.add_argument("email")
    reset.add_argument("password")
    reset.set_defaults(handler=command_set_password)

    keys = subparsers.add_parser("print-keys", help="Print the anon key.")
    keys.set_defaults(handler=command_print_keys)

    listing = subparsers.add_parser("list-users", help="Show accounts and roles.")
    listing.set_defaults(handler=command_list_users)

    args = parser.parse_args()
    if not getattr(args, "handler", None):
        parser.print_help()
        return 1

    try:
        return args.handler(args)
    except DatabaseError as error:
        print("  Database error: {}".format(error), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())

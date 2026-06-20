#!/usr/bin/env sh
set -eu
DB_URL=${DB_URL:-postgres://omnigres:omnigres@localhost:5432/omnigres}
BASE_URL=${BASE_URL:-http://localhost:8080}

contains() {
  case "$1" in
    *"$2"*) : ;;
    *) printf 'missing expected text: %s\n' "$2" >&2; exit 1 ;;
  esac
}

not_contains() {
  case "$1" in
    *"$2"*) printf 'unexpected text present: %s\n' "$2" >&2; exit 1 ;;
    *) : ;;
  esac
}

PGUI_COUNT=$(psql "$DB_URL" -v ON_ERROR_STOP=1 -Atc "select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='pgui' and p.proname = any (array['tag','text','raw','esc','frag','attrs','doc','query','form','respond_html','redirect','route']);")
[ "$PGUI_COUNT" = "12" ] || { printf 'expected 12 pgui routines, got %s\n' "$PGUI_COUNT" >&2; exit 1; }
APP_COUNT=$(psql "$DB_URL" -v ON_ERROR_STOP=1 -Atc "select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='app' and p.proname = any (array['guestbook_list','home','messages','delete_message']);")
[ "$APP_COUNT" = "4" ] || { printf 'expected 4 app handlers, got %s\n' "$APP_COUNT" >&2; exit 1; }
ROUTES=$(psql "$DB_URL" -v ON_ERROR_STOP=1 -Atc "select count(*) from omni_httpd.urlpattern_router;")
[ "$ROUTES" = "3" ] || { printf 'expected 3 routes, got %s\n' "$ROUTES" >&2; exit 1; }

PAGE=$(curl -sS -i "$BASE_URL/")
contains "$PAGE" " 200 OK"
contains "$PAGE" "content-type: text/html; charset=utf-8"
contains "$PAGE" "pgui guestbook"
contains "$PAGE" "<script src=\"https://unpkg.com/htmx.org@2\"></script>"

POSTED=$(curl -sS -X POST --data-urlencode 'author=Ada' --data-urlencode 'body=hello world' "$BASE_URL/messages")
contains "$POSTED" "hello world"
contains "$POSTED" "Ada"
LIST=$(curl -sS "$BASE_URL/messages")
contains "$LIST" "hello world"

XSS=$(curl -sS -X POST --data-urlencode 'author=x' --data-urlencode 'body=<script>alert(1)</script>' "$BASE_URL/messages")
contains "$XSS" "&lt;script&gt;alert(1)&lt;/script&gt;"
not_contains "$XSS" "<script>alert(1)</script>"

printf 'verify.sh: ok\n'

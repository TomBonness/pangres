#!/usr/bin/env sh
set -eu

DB_URL=${DB_URL:-postgres://omnigres:omnigres@localhost:5432/omnigres}
BASE_URL=${BASE_URL:-http://localhost:8080}
VERIFY_TARGET=${VERIFY_TARGET:-all}

# Normalize BASE_URL by removing trailing slash if any
BASE_URL=${BASE_URL%/}

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

# Preflight: check commands
if ! command -v psql >/dev/null 2>&1; then
  echo "Error: psql command not found. Please install postgresql client." >&2
  exit 1
fi
if ! command -v curl >/dev/null 2>&1; then
  echo "Error: curl command not found. Please install curl." >&2
  exit 1
fi

# Preflight: Check DB connectivity
if ! psql "$DB_URL" -v ON_ERROR_STOP=1 -c "select 1" >/dev/null 2>&1; then
  echo "Error: Failed to connect to the database using DB_URL: $DB_URL" >&2
  exit 1
fi

# Preflight: Check HTTP connectivity if doing demo/all verification
if [ "$VERIFY_TARGET" = "demo" ] || [ "$VERIFY_TARGET" = "all" ]; then
  if ! curl -fsS "$BASE_URL/" >/dev/null 2>&1; then
    echo "Error: Failed to connect to the HTTP server using BASE_URL: $BASE_URL/" >&2
    exit 1
  fi
fi

# ==================== FRAMEWORK MODE ====================
if [ "$VERIFY_TARGET" = "framework" ] || [ "$VERIFY_TARGET" = "all" ]; then
  echo "Verifying framework..."
  
  # 1. Confirm to_regtype('pgui.html') is not null
  HTML_TYPE_EXISTS=$(psql "$DB_URL" -v ON_ERROR_STOP=1 -Atc "select to_regtype('pgui.html') is not null;")
  if [ "$HTML_TYPE_EXISTS" != "t" ]; then
    echo "Error: pgui.html domain does not exist." >&2
    exit 1
  fi

  # 2. Confirm routines exist with intended signatures
  MISSING_ROUTINES_COUNT=$(psql "$DB_URL" -v ON_ERROR_STOP=1 -Atc "
    select count(*) from (
      select to_regprocedure('pgui.version()') as sig union all
      select to_regprocedure('pgui.esc(text)') union all
      select to_regprocedure('pgui.text(text)') union all
      select to_regprocedure('pgui.raw(text)') union all
      select to_regprocedure('pgui.frag(pgui.html[])') union all
      select to_regprocedure('pgui.attrs(jsonb)') union all
      select to_regprocedure('pgui.tag(text, jsonb, pgui.html[])') union all
      select to_regprocedure('pgui.doc(pgui.html, text, pgui.html, boolean)') union all
      select to_regprocedure('pgui.query(omni_httpd.http_request, text)') union all
      select to_regprocedure('pgui.form(omni_httpd.http_request, text)') union all
      select to_regprocedure('pgui.respond_html(pgui.html, integer)') union all
      select to_regprocedure('pgui.redirect(text, integer)') union all
      select to_regprocedure('pgui.route(text, regproc)')
    ) t where t.sig is null;
  ")
  if [ "$MISSING_ROUTINES_COUNT" -ne 0 ]; then
    echo "Error: $MISSING_ROUTINES_COUNT expected pgui routines/signatures are missing." >&2
    exit 1
  fi

  # 3. Confirm behavior with SQL assertions
  SQL_BEHAVIOR_FAILURES=$(psql "$DB_URL" -v ON_ERROR_STOP=1 -Atc "
    select count(*) from (
      select (pgui.version() = '0.1.0') as val union all
      select (pgui.esc('&<>\"''') = '&amp;&lt;&gt;&quot;&#39;') union all
      select (pgui.text('<b>x</b>')::text = '&lt;b&gt;x&lt;/b&gt;') union all
      select (pgui.attrs(jsonb_build_object('title','<x>')) = ' title=\"&lt;x&gt;\"') union all
      select (pgui.tag('br')::text = '<br>') union all
      select (pgui.tag('p','{}'::jsonb, pgui.text('x'))::text = '<p>x</p>') union all
      select (pgui.doc(pgui.tag('p','{}'::jsonb, pgui.text('x')), 'T', ''::pgui.html, false)::text LIKE '%<title>T</title>%') union all
      select (pgui.doc(pgui.tag('p','{}'::jsonb, pgui.text('x')), 'T', ''::pgui.html, false)::text NOT LIKE '%unpkg.com/htmx.org%')
    ) t where not val;
  ")
  if [ "$SQL_BEHAVIOR_FAILURES" -ne 0 ]; then
    echo "Error: $SQL_BEHAVIOR_FAILURES SQL behavior assertions failed." >&2
    exit 1
  fi
  echo "Framework verification: OK"
fi

# ==================== DEMO MODE ====================
if [ "$VERIFY_TARGET" = "demo" ] || [ "$VERIFY_TARGET" = "all" ]; then
  echo "Verifying app..."

  # 1. Confirm route mappings
  ROUTE_MAPPINGS_COUNT=$(psql "$DB_URL" -v ON_ERROR_STOP=1 -Atc "
    select count(*) from omni_httpd.urlpattern_router
    where ((match).pathname = '/' and handler::regproc::text = 'app.home')
       or ((match).pathname = '/health' and handler::regproc::text = 'app.health');
  ")
  TOTAL_ROUTES=$(psql "$DB_URL" -v ON_ERROR_STOP=1 -Atc "select count(*) from omni_httpd.urlpattern_router;")
  
  if [ "$ROUTE_MAPPINGS_COUNT" -ne 2 ] || [ "$TOTAL_ROUTES" -ne 2 ]; then
    echo "Error: Route mappings do not match expected app routes." >&2
    exit 1
  fi

  # 2. GET / and verify
  PAGE=$(curl -sS -i "$BASE_URL/")
  contains "$PAGE" "HTTP/1.1 200"
  contains "$PAGE" "<title>__PGUI_APP_NAME__</title>"
  contains "$PAGE" "<h1>__PGUI_APP_NAME__</h1>"
  contains "$PAGE" "Built with pgui."
  contains "$PAGE" "href=\"/health\""

  # 3. GET /health and verify
  HEALTH=$(curl -sS -i "$BASE_URL/health")
  contains "$HEALTH" "HTTP/1.1 200"
  contains "$HEALTH" "ok"

  echo "App verification: OK"
fi

printf 'verify.sh: ok\n'

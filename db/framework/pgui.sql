-- Pull deps (no-ops if the image already created them) and the framework schema.
create extension if not exists omni_httpd cascade;
create extension if not exists omni_web cascade;
create schema if not exists pgui;

------------------------------------------------------------------- HTML DSL
-- Safe-HTML type: a value of pgui.html is already escaped/trusted markup.
-- The only way to get untrusted text in is pgui.text() (escapes) or pgui.raw() (explicit trust).
create domain pgui.html as text;

create or replace function pgui.esc(t text) returns text language sql immutable as $$
  select replace(replace(replace(replace(replace(coalesce(t,''),
    '&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;'),'''','&#39;')
$$;

create or replace function pgui.text(t text) returns pgui.html language sql immutable as $$
  select pgui.esc(t)::pgui.html                       -- untrusted -> escaped safe html
$$;

create or replace function pgui.raw(t text) returns pgui.html language sql immutable as $$
  select coalesce(t,'')::pgui.html                    -- explicit trust (heredoc static markup)
$$;

create or replace function pgui.frag(variadic children pgui.html[]) returns pgui.html
  language sql immutable as $$
  select coalesce(array_to_string(children,''),'')::pgui.html
$$;

-- Attributes from a jsonb object; values are escaped. {"class":"x","hx-get":"/y","autofocus":""}.
create or replace function pgui.attrs(j jsonb) returns text language sql immutable as $$
  select coalesce(string_agg(' '||key||'="'||pgui.esc(value)||'"',''),'')
  from jsonb_each_text(coalesce(j,'{}'::jsonb))
$$;

-- Element builder. Void elements get no closing tag. Children are already-safe pgui.html.
create or replace function pgui.tag(name text, attrs jsonb default '{}'::jsonb,
                                    variadic children pgui.html[] default array[]::pgui.html[])
  returns pgui.html language sql immutable as $$
  select (case when lower(name) = any (array['area','base','br','col','embed','hr',
            'img','input','link','meta','param','source','track','wbr'])
    then '<'||name||pgui.attrs(attrs)||'>'
    else '<'||name||pgui.attrs(attrs)||'>'||coalesce(array_to_string(children,''),'')||'</'||name||'>'
  end)::pgui.html
$$;

-- Page shell / layout: doctype + head (htmx + Pico CSS) + <main>body</main>.
create or replace function pgui.doc(body pgui.html, title text default 'pgui',
                                    head pgui.html default ''::pgui.html)
  returns pgui.html language sql immutable as $$
  select pgui.raw(
    '<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">'||
    '<meta name="viewport" content="width=device-width, initial-scale=1">'||
    '<title>'||pgui.esc(title)||'</title>'||
    '<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@picocss/pico@2/css/pico.min.css">'||
    '<script src="https://unpkg.com/htmx.org@2"></script>'||
    head||'</head><body><main class="container">'||body||'</main></body></html>')
$$;

----------------------------------------------------------------- REQUEST API
-- Query-string param. request.query_string may be NULL.
create or replace function pgui.query(request omni_httpd.http_request, key text) returns text
  language sql stable as $$
  select omni_web.param_get(omni_web.parse_query_string(coalesce(request.query_string,'')), key)
$$;

-- Form field from an application/x-www-form-urlencoded body (request.body is bytea, may be NULL).
create or replace function pgui.form(request omni_httpd.http_request, key text) returns text
  language sql stable as $$
  select omni_web.param_get(
           omni_web.parse_query_string(convert_from(coalesce(request.body,''::bytea),'utf8')), key)
$$;

---------------------------------------------------------------- RESPONSE API
create or replace function pgui.respond_html(body pgui.html, status int default 200)
  returns omni_httpd.http_outcome language sql as $$
  select omni_httpd.http_response(body => body::text, status => status,
           headers => array[omni_http.http_header('content-type','text/html; charset=utf-8')])
$$;

create or replace function pgui.redirect(location text, status int default 303)
  returns omni_httpd.http_outcome language sql as $$
  select omni_httpd.http_response(status => status,
           headers => array[omni_http.http_header('location', location)])
$$;

-------------------------------------------------------------------- ROUTING
-- Register path -> handler in the default router. method => NULL matches any method
-- (handlers branch on request.method themselves; see Assumptions for why path-only routing).
create or replace procedure pgui.route(path text, handler regproc) language sql as $$
  insert into omni_httpd.urlpattern_router (match, handler)
  values (omni_httpd.urlpattern(pathname => path), handler);
$$;

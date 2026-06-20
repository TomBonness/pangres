# pgui

`pgui` is a tiny full-stack web framework where Postgres is the web server: Omnigres `omni_httpd` runs inside the database process, routes HTTP requests to SQL handlers, and those handlers render safe HTML with the reusable `pgui` schema. The demo guestbook is server-rendered hypermedia: htmx is the only browser JavaScript, and all application logic, routing, persistence, and HTML rendering live in SQL.

## Run

```sh
./run.sh
psql 'postgres://omnigres:omnigres@localhost:5432/omnigres' -v ON_ERROR_STOP=1 -f db/install.sql
./verify.sh
```

Open <http://localhost:8080/>.

`run.sh` starts a clean Omnigres container named `pgui`; re-running it resets the database. The script maps host port `8080` to the Omnigres HTTP listener in the container.

## Author a route

Create a SQL handler that accepts `omni_httpd.http_request` and returns `omni_httpd.http_outcome`, then register it with `pgui.route`:

```sql
create or replace function app.hello(request omni_httpd.http_request)
  returns omni_httpd.http_outcome language sql as $$
  select pgui.respond_html(pgui.doc(
    pgui.tag('p', '{}', pgui.text('Hello from Postgres')),
    'hello'));
$$;

call pgui.route('/hello', 'app.hello');
```

Use `pgui.text()` for untrusted text, `pgui.raw()` only for trusted static markup, and `pgui.tag()` / `pgui.attrs()` for escaped HTML attributes. Boolean attributes can be rendered with an empty string value, e.g. `jsonb_build_object('required','')`.

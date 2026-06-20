# Tutorial: Interactive Guestbook

This tutorial guides you through the structure and implementation of the interactive guestbook demo bundled with `pgui`. This application demonstrates how to handle persistence, define HTML pages and fragments, process forms, and integrate htmx, all using PostgreSQL SQL handlers.

## Directory Structure

A standard `pgui` application divides its database code under `db/app/` as follows:
- `schema.sql`: Table structure and storage definitions.
- `handlers.sql`: Functions that receive HTTP requests and return HTTP outcomes.
- `routes.sql`: Maps routes to handlers in the router.
- `install.sql`: Sequential script that includes the schema, handlers, and routes.

---

## 1. Data Schema (`schema.sql`)

The guestbook data is stored in a single table, `app.guestbook`:
```sql
create schema if not exists app;

create table if not exists app.guestbook (
  id         bigint generated always as identity primary key,
  author     text not null,
  body       text not null,
  created_at timestamptz not null default now()
);
```

---

## 2. Request Handlers (`handlers.sql`)

Handlers in `pgui` are PostgreSQL functions that accept `omni_httpd.http_request` and return `omni_httpd.http_outcome`.

### A. Rendering a List Fragment

The `app.guestbook_list()` function queries the database and renders a list of guestbook entries:
```sql
create or replace function app.guestbook_list() returns pgui.html language sql stable as $$
  select case when count(*) = 0 then
    pgui.tag('p', '{}', pgui.text('No messages yet.'))
  else
    pgui.frag(variadic array_agg(
      pgui.tag('article', '{}',
        pgui.tag('header', '{}',
          pgui.text(g.author||' · '||to_char(g.created_at,'HH24:MI:SS'))),
        pgui.text(g.body),
        pgui.tag('button',
          jsonb_build_object('type','button','class','secondary','hx-post','/messages/delete',
            'hx-vals', json_build_object('id', g.id)::text,
            'hx-target','#list','hx-swap','innerHTML',
            'aria-label', 'Delete message from ' || g.author),
          pgui.text('delete'))
      ) order by g.id desc))
  end
  from app.guestbook g;
$$;
```

#### Key Concepts:
1. **XSS Safety**: User inputs (`g.author` and `g.body`) are processed using `pgui.text()`. This automatically escapes HTML special characters to prevent XSS injection.
2. **htmx Integration**: The delete button has `hx-post="/messages/delete"`, `hx-vals` containing the message ID, and `hx-target="#list"` to refresh the message container dynamically.
3. **Accessibility**: The delete button features an `aria-label` attribute specifically announcing which message will be deleted, assisting screen-reader users.

### B. The Home Page Handler (`app.home`)

The home page handler renders the complete HTML document containing the entry form and the list container:
```sql
create or replace function app.home(request omni_httpd.http_request)
  returns omni_httpd.http_outcome language sql as $$
  select pgui.respond_html(pgui.doc(
    pgui.frag(
      pgui.tag('h1', '{}', pgui.text('pgui guestbook — served by Postgres')),
      pgui.tag('form',
        jsonb_build_object('hx-post','/messages','hx-target','#list','hx-swap','innerHTML',
                           'hx-on::after-request','this.reset()'),
        pgui.tag('label', jsonb_build_object('for','author'), pgui.text('Name')),
        pgui.tag('input', jsonb_build_object('id','author','name','author','autocomplete','name','placeholder','Ada')),
        pgui.tag('label', jsonb_build_object('for','body'), pgui.text('Message')),
        pgui.tag('input', jsonb_build_object('id','body','name','body','required','','aria-describedby','message-help','placeholder','Write a message')),
        pgui.tag('small', jsonb_build_object('id','message-help'), pgui.text('Required. Plain text is escaped before display.')),
        pgui.tag('button', jsonb_build_object('type','submit'), pgui.text('Post'))),
      pgui.tag('div',
        jsonb_build_object('id','list','hx-get','/messages',
                           'hx-trigger','load, every 3s','hx-swap','innerHTML',
                           'role','status','aria-live','polite'),
        app.guestbook_list())),
    'pgui guestbook'));
$$;
```

#### Key Concepts:
1. **`pgui.doc`**: Generates a standard full HTML page structure (incorporating Pico CSS and htmx by default).
2. **Accessible Forms**: Inputs are paired with visible `<label>` elements linked via `for` and `id` attributes. Descriptions are linked via `aria-describedby`.
3. **Live Regions**: The `#list` container has `role="status"` and `aria-live="polite"` so screen-readers announce new list elements added via dynamic updates or periodic polling.

### C. Handlers with Method Branching (`app.messages`)

`pgui` handlers can branch behavior based on the incoming HTTP method:
```sql
create or replace function app.messages(request omni_httpd.http_request)
  returns omni_httpd.http_outcome language plpgsql as $$
declare _author text; _body text;
begin
  if upper(request.method::text) = 'POST' then
    _author := coalesce(nullif(trim(pgui.form(request,'author')),''),'anon');
    _body   := nullif(trim(pgui.form(request,'body')),'');
    if _body is not null then
      insert into app.guestbook(author, body) values (_author, _body);
    end if;
  end if;
  return pgui.respond_html(app.guestbook_list());
end$$;
```

#### Key Concepts:
1. **Form Processing**: `pgui.form(request, 'key')` parses form parameters from the application/x-www-form-urlencoded request body.
2. **Conditional Executions**: The PL/pgSQL block inspects `request.method` to perform inserts on `POST` requests while responding with the list fragment for both `GET` and `POST`.

### D. Delete Handler (`app.delete_message`)

This handler deletes a message and returns the updated list fragment:
```sql
create or replace function app.delete_message(request omni_httpd.http_request)
  returns omni_httpd.http_outcome language plpgsql as $$
begin
  delete from app.guestbook where id = (nullif(trim(pgui.form(request,'id')),''))::bigint;
  return pgui.respond_html(app.guestbook_list());
exception when invalid_text_representation then
  return pgui.respond_html(app.guestbook_list());
end$$;
```

---

## 3. Routes Configuration (`routes.sql`)

Routes are registered using `pgui.route(path, handler_regproc)`:
```sql
-- Reset the router mappings first
delete from omni_httpd.urlpattern_router;

call pgui.route('/',                'app.home');
call pgui.route('/messages',        'app.messages');
call pgui.route('/messages/delete', 'app.delete_message');
```
Because the router evaluates mappings sequentially, resetting previous routes first ensures deterministic mapping resolution.

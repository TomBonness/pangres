# Routing and Requests

This guide explains how `pgui` handles incoming HTTP requests, how to map request URLs to database functions, and how to write handlers that branch on HTTP methods.

## The Handler Contract

All request handlers in `pgui` must adhere to a specific PostgreSQL function signature:
- **Input**: Exactly one parameter of type `omni_httpd.http_request`.
- **Output**: Returns `omni_httpd.http_outcome`.

An `http_request` is a composite type containing request details such as method, path, headers, query string, and body:
- `request.method`: `omni_http.http_method` (e.g. `GET`, `POST`, `DELETE`).
- `request.path`: `text` representing the request path.
- `request.query_string`: `text` representing raw query parameters.
- `request.body`: `bytea` containing the raw request body payload.

### Basic Handler Example
```sql
create or replace function app.hello(request omni_httpd.http_request)
  returns omni_httpd.http_outcome language sql as $$
  select pgui.respond_html(
    pgui.doc(
      pgui.tag('p', '{}', pgui.text('Hello World!')),
      'Hello'
    )
  );
$$;
```

---

## Route Registration

`pgui` uses path-only routing. Routes are registered globally in the database using the `pgui.route` procedure:
```sql
call pgui.route(path_pattern, handler_procedure);
```

### Route Pattern Format
Paths use standard URL patterns (under the hood, mapped to `omni_httpd.urlpattern` pathname matching):
- `/`: Exact match for the root path.
- `/messages`: Exact match for `/messages`.
- `/user/:id`: Path parameters (can be extracted using Omnigres request methods if needed).

---

## Handling HTTP Methods (Method Branching)

Because the route mapping registration is path-only, method-based routing belongs inside the handler functions themselves. Handlers check the `request.method` field and execute the appropriate database queries or render the correct fragments.

### Pattern: GET and POST Branching

A common pattern for interactive forms is handling `GET` (render initial state or fragment) and `POST` (process form submission, modify database, and return refreshed fragment) in a single handler.

Here is the implementation of `/messages` from the guestbook demo:
```sql
create or replace function app.messages(request omni_httpd.http_request)
  returns omni_httpd.http_outcome language plpgsql as $$
declare
  _author text;
  _body text;
begin
  -- Branch behavior based on HTTP method
  if upper(request.method::text) = 'POST' then
    -- Parse form parameters from urlencoded request body
    _author := coalesce(nullif(trim(pgui.form(request, 'author')), ''), 'anon');
    _body   := nullif(trim(pgui.form(request, 'body')), '');
    
    if _body is not null then
      -- Perform database insert
      insert into app.guestbook (author, body) values (_author, _body);
    end if;
  end if;

  -- Both GET and POST return the updated guestbook list HTML fragment
  return pgui.respond_html(app.guestbook_list());
end$$;
```

### Best Practices:
1. **Case Normalization**: Always wrap `request.method` comparisons in `upper(request.method::text)` to make checks case-insensitive.
2. **Post-Redirect-Get (PRG) alternative**: If you are not using htmx and want to prevent form resubmission on page reload, return a redirect response instead of the HTML fragment:
   ```sql
   if upper(request.method::text) = 'POST' then
     -- process form...
     return pgui.redirect('/success');
   end if;
   ```

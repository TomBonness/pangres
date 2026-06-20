# API Reference

This document lists the public schemas, domains, functions, and procedures provided by the `pgui` web framework.

---

## Types & Domains

### `pgui.html`
- **Type**: `domain` over `text`
- **Purpose**: Represents safe, trusted, or escaped HTML markup. Passing values of this type protects against cross-site scripting (XSS).
- **Example**:
  ```sql
  select '`<p>Hello</p>`'::pgui.html;
  ```

---

## Core Functions

### `pgui.version()`
- **Signature**: `pgui.version() returns text`
- **Purpose**: Returns the current version of the pgui framework.
- **Null Behavior**: Never returns NULL.
- **Example**:
  ```sql
  select pgui.version(); -- '0.1.0'
  ```

### `pgui.esc(text)`
- **Signature**: `pgui.esc(t text) returns text`
- **Purpose**: Escapes special characters (`&`, `<`, `>`, `"`, `'`) for safe inclusion in HTML.
- **Null Behavior**: Returns empty string if input is NULL.
- **Example**:
  ```sql
  select pgui.esc('`A & B < C>`'); -- 'A &amp; B &lt; C&gt;'
  ```

### `pgui.text(text)`
- **Signature**: `pgui.text(t text) returns pgui.html`
- **Purpose**: Converts raw text into safe HTML by escaping special characters.
- **Null Behavior**: Returns empty html if input is NULL.
- **Example**:
  ```sql
  select pgui.text('`<b>Hi</b>`'); -- '&lt;b&gt;Hi&lt;/b&gt;'
  ```

### `pgui.raw(text)`
- **Signature**: `pgui.raw(t text) returns pgui.html`
- **Purpose**: Explicitly trusts a text string as pre-escaped safe HTML.
- **Null Behavior**: Returns empty html if input is NULL.
- **Example**:
  ```sql
  select pgui.raw('`<p>trusted markup</p>`');
  ```

### `pgui.frag(VARIADIC pgui.html[])`
- **Signature**: `pgui.frag(variadic children pgui.html[]) returns pgui.html`
- **Purpose**: Combines multiple HTML fragments into a single HTML structure.
- **Null Behavior**: Returns empty html if array is empty or contains only NULL.
- **Example**:
  ```sql
  select pgui.frag(pgui.text('A'), pgui.text('B')); -- 'AB'
  ```

### `pgui.attrs(jsonb)`
- **Signature**: `pgui.attrs(j jsonb) returns text`
- **Purpose**: Transforms a JSONB key-value object into a string of HTML attributes with escaped values.
- **Null Behavior**: Returns empty string if input is NULL.
- **Example**:
  ```sql
  select pgui.attrs('`{"class": "btn", "id": "<my-id>"}`'::jsonb); -- ' class="btn" id="&lt;my-id&gt;"'
  ```

### `pgui.tag(text, jsonb, VARIADIC pgui.html[])`
- **Signature**:
  ```sql
  pgui.tag(
    name text,
    attrs jsonb default '{}'::jsonb,
    variadic children pgui.html[] default array[]::pgui.html[]
  ) returns pgui.html
  ```
- **Purpose**: Builds an HTML tag with the specified name, attributes, and children. Void elements (like `input`, `br`, `link`, etc.) do not render closing tags.
- **Example**:
  ```sql
  select pgui.tag('p', '`{"class": "lead"}`'::jsonb, pgui.text('Hello')); -- '<p class="lead">Hello</p>'
  ```

### `pgui.doc(pgui.html, text, pgui.html, boolean)`
- **Signature**:
  ```sql
  pgui.doc(
    body pgui.html,
    title text default 'pgui',
    head pgui.html default ''::pgui.html,
    include_defaults boolean default true
  ) returns pgui.html
  ```
- **Purpose**: Generates a full HTML document layout. When `include_defaults` is true, includes Pico CSS and htmx CDN scripts.
- **Example**:
  ```sql
  select pgui.doc(pgui.text('body text'), 'My App', ''::pgui.html, false);
  ```

---

## Request Functions

### `pgui.query(omni_httpd.http_request, text)`
- **Signature**: `pgui.query(request omni_httpd.http_request, key text) returns text`
- **Purpose**: Retrieves a query string parameter by key from an HTTP request.
- **Null Behavior**: Returns NULL if query parameter is not present.
- **Example**:
  ```sql
  select pgui.query(request, 'search');
  ```

### `pgui.form(omni_httpd.http_request, text)`
- **Signature**: `pgui.form(request omni_httpd.http_request, key text) returns text`
- **Purpose**: Retrieves a form field value by key from a POST request body (`application/x-www-form-urlencoded`).
- **Null Behavior**: Returns NULL if parameter is not present.
- **Example**:
  ```sql
  select pgui.form(request, 'username');
  ```

---

## Response Functions

### `pgui.respond_html(pgui.html, integer)`
- **Signature**: `pgui.respond_html(body pgui.html, status int default 200) returns omni_httpd.http_outcome`
- **Purpose**: Creates an HTTP HTML response with `content-type: text/html; charset=utf-8` header and the specified status code.
- **Example**:
  ```sql
  select pgui.respond_html(pgui.text('Welcome!'), 200);
  ```

### `pgui.redirect(text, integer)`
- **Signature**: `pgui.redirect(location text, status int default 303) returns omni_httpd.http_outcome`
- **Purpose**: Creates an HTTP redirect response with a location header and status code.
- **Example**:
  ```sql
  select pgui.redirect('/home');
  ```

---

## Routing Procedures

### `pgui.route(text, regproc)`
- **Signature**: `pgui.route(path text, handler regproc)`
- **Purpose**: Registers a path pattern to a specific request handler function in the default Omnigres router.
- **Example**:
  ```sql
  call pgui.route('/about', 'app.about');
  ```

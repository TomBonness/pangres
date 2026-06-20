# Security and Accessibility

This document outlines the safety conventions, accessibility principles, and current security limitations when building applications with `pgui`.

---

## Security Guidelines

### 1. Cross-Site Scripting (XSS) Prevention

`pgui` uses the `pgui.html` domain type to guarantee that strings passed to rendering functions are already escaped and trusted.

- **`pgui.text(text)`**: Converts untrusted user input into safe HTML by escaping `<`, `>`, `&`, `"`, and `'`. **Always** use this when outputting database records, query string values, or form inputs.
  ```sql
  -- Safe
  pgui.tag('p', '{}', pgui.text(user.bio))
  ```
- **`pgui.raw(text)`**: Directly casts raw text into the `pgui.html` domain without escaping. **Never** pass user input or unvalidated strings to `pgui.raw()`. Use it only for trusted static layouts or hardcoded page structures.
  ```sql
  -- Safe for static scaffolding only
  pgui.raw('<div>')
  ```

### 2. Attribute Escaping

Attributes constructed using `pgui.attrs(jsonb)` are automatically escaped:
- Values are escaped via `pgui.esc()`.
- Double quotes surrounding attribute values are handled automatically.
- E.g. `jsonb_build_object('placeholder', '<Name>')` becomes `placeholder="&lt;Name&gt;"`.

**Important Limitation**: Tag names and attribute keys (names) are not escaped by `pgui` and must remain strictly developer-controlled. Do not construct tag names (e.g. `<tag_name>`) or attribute names dynamically from user input.

### 3. Missing Security Features (Roadmap)

`pgui` `0.1.0` does not currently include built-in handlers for:
- **CSRF Protection**: When processing modifying requests (POST/PUT/DELETE) without htmx or outside of APIs, ensure you implement verification tokens.
- **Authentication & Authorization**: Session storage, JWT verification, and user permission checks must be handled at the schema level or via custom helper functions.
- **Rate Limiting**: IP-based rate limiting or request throttling must be handled by an upstream reverse proxy (like Nginx) or a custom PL/pgSQL middleware function.

---

## Accessibility (a11y) Guidelines

Creating accessible web applications is a key goal of `pgui`. We follow W3C WAI (Web Accessibility Initiative) guidelines.

### 1. Form Markup

All form controls must be accessible to assistive technologies:
- **Visible Labels**: Do not rely on `placeholder` attributes alone for identifying form inputs. Pair every input with a `<label>` element.
- **Explicit Links**: Associate the label to its input using matching `for` and `id` attributes.
- **Descriptions**: Use `aria-describedby` to link input fields to inline instructions or validation error messages.

```sql
pgui.frag(
  pgui.tag('label', jsonb_build_object('for', 'username'), pgui.text('Username')),
  pgui.tag('input', jsonb_build_object('id', 'username', 'name', 'username', 'aria-describedby', 'username-help')),
  pgui.tag('small', jsonb_build_object('id', 'username-help'), pgui.text('Required. Min 3 characters.'))
)
```

### 2. Repeated Action Controls

In lists of elements where actions are repeated (like a "delete" button next to every item in a list):
- Provide clear context to screen readers by setting an `aria-label` attribute.
- Ensure the label describes the action and the specific item it affects (e.g., `Delete message from Tom`).

```sql
pgui.tag('button',
  jsonb_build_object(
    'type', 'button',
    'aria-label', 'Delete message from ' || msg.author,
    'hx-post', '/delete'
  ),
  pgui.text('delete')
)
```

### 3. Dynamic Updates (htmx Live Regions)

When using htmx to dynamically update fragments of a page without performing a full reload:
- Screen readers need to be notified of the updates.
- Apply `role="status"` and `aria-live="polite"` to the container element where the content is injected. This ensures the updated content is announced politely without interrupting current reader actions.

```sql
pgui.tag('div',
  jsonb_build_object(
    'id', 'list',
    'role', 'status',
    'aria-live', 'polite'
  ),
  app.list_content()
)
```

# Roadmap

This document outlines the planned work and future directions for the `pgui` web framework.

---

## Near-Term Framework Features

### 1. Routing Improvements
- **Method-Aware/Idempotent Routing**: Support registering routes specifically for `GET`, `POST`, `PUT`, `DELETE` rather than relying entirely on manual branching inside handlers.
- **Route Removal/Scoped Clearing**: Add procedures to remove specific path mappings (`pgui.remove_route('/path')`) or clear routes for a specific namespace/app, avoiding the need for brute-force tables deletion (`delete from omni_httpd.urlpattern_router`).

### 2. Request & Parameter Helpers
- **Typed Required/Default Param Helpers**: Add helpers to extract parameters directly cast to specific PostgreSQL types (e.g. `pgui.form_int`, `pgui.query_uuid`) with automated validation error hooks.
- **Content-Type Validation**: Implement helpers to check incoming request `Content-Type` headers easily.

### 3. Response Helpers
- **Response Utilities**: Add response helpers for common media formats, such as `pgui.respond_json(jsonb)`, `pgui.respond_text(text)`, as well as helpers to set custom HTTP headers and cookie headers (`pgui.cookie`).

### 4. Rendering Security
- **Validated Tag/Attribute Names**: Validate element names in `pgui.tag` and attribute names in `pgui.attrs` against strict alphanumeric rules to completely prevent injection through developer-controlled fields.

### 5. Configurable Assets and Layouts
- **Layout Management**: Allow layouts to be dynamically selected or configured per schema/app.
- **Asset Pipelines**: Standardize static asset hosting and path mapping under `/assets/` inside Omnigres.

### 6. Security & Grants
- **Grants/Roles Integration**: Document and simplify how database permission roles block/allow execution of specific handler procedures dynamically.

### 7. Packaging & Version Upgrades
- **PostgreSQL Extension Packaging**: Package `pgui` as a formal PostgreSQL extension (`CREATE EXTENSION pgui`) rather than running `.sql` installer files.
- **Upgrade Scripts**: Provide automatic SQL upgrade scripts for migrating schema domains and framework tables across versions.

---

## Adoption Work

To make `pgui` widely adoptable and foster a community, we plan to focus on the following resources:

### 1. Developer Resources
- **Documentation Site**: Publish a static site (using VitePress or similar) hosting these guides, search, and copyable snippets.
- **Examples Gallery**: Add an `examples/` directory showing common integrations:
  - Todo MVC with htmx.
  - Multi-page dashboard with database-driven navigation.
  - JSON API with token authorization.
- **Screencasts**: Produce a "build a blog in 10 minutes using SQL" video.

### 2. Community & Maintenance
- **Release Notes**: Publish structured changelogs for minor/major releases.
- **Issue Triage**: Establish standard label categories and issue templates for community bugs.
- **Plugins/Recipes**: Maintain a repository of copy-paste SQL snippets for common tasks like JWT validation, session handling, and CORS setup.
- **Dogfooded Apps**: Build and host a few production services using `pgui` to continuously validate API ergonomics.

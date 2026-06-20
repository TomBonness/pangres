# pgui

`pgui` is a full-stack web framework where PostgreSQL is the web server. Omnigres `omni_httpd` runs directly inside the database process, routing HTTP requests to SQL handlers that render XSS-safe HTML using a powerful SQL DSL. While htmx is first-class and enabled by default for hypermedia-driven interfaces, it is entirely optional. With `pgui`, your application logic, database, routing, and HTML rendering live together in clean, testable SQL.

## Quick start

To start the development server and install the guestbook demo:
```sh
./run.sh
```

To run the verification suite:
```sh
./verify.sh
```

To generate a new pgui application from a starter template:
```sh
bin/create-pgui-app hello_pgui
```

## What you get

- **SQL HTML DSL**: Render type-safe and automatically escaped HTML templates using `pgui.tag`, `pgui.attrs`, and `pgui.frag`.
- **Request Helpers**: Easily parse form submissions (`pgui.form`) and query strings (`pgui.query`).
- **Response Helpers**: Return HTML outcomes (`pgui.respond_html`) and redirects (`pgui.redirect`).
- **Route Registration**: Map URLs directly to SQL handlers using `pgui.route`.
- **One-Command Docker Dev Server**: Fast, isolated local development environment powered by Omnigres via `run.sh`.
- **Starter Generator**: Scaffold new application structures instantly with `bin/create-pgui-app`.
- **Accessible Guestbook Demo**: A built-in, W3C WAI-compliant, htmx-enhanced interactive guestbook.

## Install only the framework

To install only the `pgui` schema and routines into an existing PostgreSQL database:
```sh
psql "$DB_URL" -v ON_ERROR_STOP=1 -f db/framework/install.sql
```

## Learn

Explore the documentation to master building applications with `pgui`:

- [Getting Started](docs/getting-started.md) — Prerequisites, environment variables, configuration, and troubleshooting.
- [Tutorial: Interactive Guestbook](docs/tutorial-guestbook.md) — Step-by-step guide to schemas, handlers, method-branching, and htmx.
- [API Reference](docs/api.md) — Complete function and procedure signatures, descriptions, and examples.
- [Routing and Requests](docs/routing-and-requests.md) — The request handler contract, path-matching, and handling HTTP methods.
- [Security and Accessibility](docs/security-and-accessibility.md) — XSS prevention, form markup guidelines, live regions, and CSRF notes.
- [Deployment](docs/deployment.md) — Production Docker setups, proxying, AWS/managed database limitations.
- [Roadmap](docs/roadmap.md) — Near-term features and community/ecosystem adoption plans.
- [Releasing](docs/releasing.md) — Guidelines and checklists for releasing new versions of the framework.

## Status

`0.1.0` experimental: good for demos and exploration; APIs may change before 1.0.

## License

Distributed under the MIT License. See [LICENSE](LICENSE) for details.

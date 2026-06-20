# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-06-20

### Added
- **Framework installer split**: Divided SQL definitions so the core `pgui` framework can be installed independently from the guestbook demo application.
- **Starter generator**: Added `bin/create-pgui-app` to scaffold new applications using a basic templates setup.
- **Accessible guestbook demo**: Upgraded the guestbook demo inputs with visible labels, a dynamic live region (`aria-live="polite"`), and clear delete actions (`aria-label`) to comply with accessibility standard guidelines.
- **Developer workflow**: Overhauled `run.sh` to make ports, containers, database configuration, and SQL installers customizable via environment variables, avoiding destructive resets by default.
- **Documentation**: Wrote thematic manuals, tutorials, security/accessibility guidelines, and API references under `docs/`.

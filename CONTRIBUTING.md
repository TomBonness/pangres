# Contributing to pgui

Thank you for your interest in contributing to `pgui`! We welcome bug reports, feature requests, documentation improvements, and pull requests.

## Local Development Setup

To set up a local development workspace:
1. Make sure you have Docker, a POSIX shell, `curl`, and `psql` client installed on your host machine.
2. Clone the repository and run the local development server:
   ```sh
   ./run.sh
   ```
3. Run the verification tests to confirm everything is running correctly:
   ```sh
   ./verify.sh
   ```

## Coding Conventions

- **SQL Files**: Core framework features go inside `db/framework/pgui.sql`. Demo/app specific code remains under `db/app/`.
- **Security**: Any handler code accepting user input must wrap output values in `pgui.text()` to escape HTML special characters. Never use `pgui.raw()` on untrusted strings.
- **Accessibility**: When authoring templates or handlers, ensure form inputs are properly associated with visible labels and interactive elements have clear accessible labels.

## Pull Request Checklist

Before submitting your pull request, ensure you have:
1. Run `./verify.sh` locally and verified that all checks pass in both framework and demo modes.
2. Verified that code conventions are maintained.
3. Added or updated documentation under `docs/` for any new routines or architectural patterns.

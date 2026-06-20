# Releasing pgui

This guide outlines the checklist and procedure for publishing a new version of the `pgui` framework.

---

## Release Checklist

Before releasing a new version, complete the following steps in order:

### 1. Update Version Identifiers
- Update the version string in the root `VERSION` file (e.g. `0.1.0`).
- Update the return value of `pgui.version()` in `db/framework/pgui.sql` so it returns the exact same version string.
- Update version metadata in template generators (`templates/basic/`) if applicable.

### 2. Update Documentation
- Ensure any new SQL routines are fully documented in `docs/api.md`.
- Ensure new concepts are updated in relevant thematic guides.

### 3. Update Changelog
- Edit `CHANGELOG.md`.
- Move the contents of the `## Unreleased` section to a new version header (e.g., `## [0.1.0] - 2026-06-20`).
- Create a new, blank `## Unreleased` section at the top of the file.

### 4. Run the Verification Suite
You must run the complete suite of verification checks in all modes:

```sh
# 1. Clean root verification (Framework + Demo)
PGUI_RESET=1 ./run.sh
./verify.sh

# 2. Scoped framework verification
VERIFY_TARGET=framework ./verify.sh

# 3. Scoped demo verification
VERIFY_TARGET=demo ./verify.sh

# 4. Starter generator E2E verification
rm -rf /tmp/hello-pgui
bin/create-pgui-app hello_pgui /tmp/hello-pgui
cd /tmp/hello-pgui
PGUI_CONTAINER=pgui-template PGUI_DB_PORT=55433 PGUI_HTTP_PORT=18081 PGUI_RESET=1 ./run.sh
DB_URL=postgres://omnigres:omnigres@localhost:55433/omnigres BASE_URL=http://localhost:18081 ./verify.sh
```

---

## Tagging & Publishing

Once all tests pass:

1. Commit all version changes and changelog updates:
   ```sh
   git commit -am "release: v0.1.0"
   ```
2. Create a signed git tag using the `v*` format:
   ```sh
   git tag -s v0.1.0 -m "Release v0.1.0"
   ```
3. Push commits and tags to GitHub:
   ```sh
   git push origin main --tags
   ```
4. Create the Release on GitHub:
   - Use the tag name (e.g., `v0.1.0`).
   - Copy-paste the version's changelog section into the release description.
   - Highlight any breaking API changes or migration steps.

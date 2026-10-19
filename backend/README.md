# Backend

Rails 8.1 API. This is the first runtime in the repo. Web and mobile clients are not in this repository yet. The HTTP contract of this app is what those clients will share.

Ruby 3.4.11. Local and test databases are SQLite files under `storage/`, which git ignores.

## Run

From this directory:

```bash
bundle install
bin/rails db:prepare
bin/rails server
```

`GET /up` returns 200 when the process booted. That route is the walking skeleton and the uptime check.

From the repository root, `bin/ci` runs the same gate as a pull request: setup, RuboCop, bundler-audit, Brakeman, and the test suite.

GitHub Actions for this app live at the repository root, in `.github/workflows/ci.yml`. A workflow nested under `backend/.github` would not run.

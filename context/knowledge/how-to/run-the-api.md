# Run the API

Requirements: Ruby 3.4.11, Bundler, and SQLite headers. `backend/.ruby-version` pins the version. Ruby 3.2 is past end of life, and the security scan fails the build on it.

```bash
cd backend
bundle install
bin/rails db:prepare
bin/rails server
```

`GET /up` returns 200 when the process booted.

The repository gate, from the root:

```bash
bin/ci
```

That runs gem setup, RuboCop, bundler-audit, Brakeman, and the Rails tests. A change is not done until it exits 0.

`config/master.key` stays on your machine. It is gitignored. Do not paste it into a prompt.

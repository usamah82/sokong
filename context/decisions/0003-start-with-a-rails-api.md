# ADR-0003: Start with a Rails API

## Status

Accepted

## Date

2026-10-19

## Context

The intended shape is a Rails backend, a web frontend, and a mobile frontend. None of those clients can be designed honestly before the product domain exists. The backend can exist now as a contract both clients will share.

We need a test gate agents can run without extra services.

## Decision

The first runtime is an API-only Rails 8.1 app in `backend/` (Ruby module `Backend`, Ruby 3.4.11). Ruby 3.2 is past end of life, and Brakeman fails the gate on it. Local and test databases are SQLite files under `storage/`. The first behavior is `GET /up`.

Web and mobile apps are not scaffolded. When they start, they are sibling directories, and they talk to this API. Do not version the URL space until a second client needs a change the first client cannot take.

`bin/ci` at the repository root is the gate. It delegates to the Rails continuous-integration script (RuboCop, bundler-audit, Brakeman, tests).

Production host, production database, and deploy credentials are not decided. `config/deploy.yml` is the file Rails generated. The address in it is a placeholder.

## Alternatives Considered

### Rails app at the repository root

- Pros: matches a single-app Rails repo
- Cons: web and mobile would then sit inside the Rails tree or force a later move
- Rejected: the API is one of three future surfaces

### PostgreSQL from day one

- Pros: closer to a typical production database
- Cons: every agent needs a running server before the suite is green
- Rejected for local and test: SQLite is the Rails default we generated. Choosing PostgreSQL for production is a later ADR, made when there is data worth hosting.

### Generate the web client now

- Pros: something to click
- Cons: no product to show, and a client would freeze API guesses
- Rejected: the API health check is the walking skeleton

## Consequences

- CORS stays closed until a client origin is named.
- `config/master.key` is local. CI does not need it while boot does not read credentials.
- Kamal, Docker, and the deploy file are present so a later deploy agent has a starting point. They are not permission to ship.

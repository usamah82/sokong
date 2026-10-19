# Vision

The product domain is not chosen. There is no user, no promise, and no name yet. Do not invent one in a spec or a UI.

What exists today is a place to build that product with agents:

- A Rails 8.1 API in `backend/`, so web and mobile clients can share one contract later.
- A context tree, so a new agent can continue without the previous chat.
- The [agent-skills](https://github.com/addyosmani/agent-skills) workflows, pinned, plus one repo skill that says where files go.

The first real feature starts when a human can say who it is for and what changes for them. Until then, the only behavior the API owes anyone is `GET /up`.

Web and mobile clients are intentionally absent. Adding either before an approved API contract would freeze a guess.

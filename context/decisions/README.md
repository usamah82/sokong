# Decisions

ADRs are append-only. The next number is 0009. Match the headings in the existing files: Status, Date, Context, Decision, Alternatives Considered, Consequences.

`.adr-dir` at the repository root points here so `documentation-and-adrs` does not start a second sequence under `docs/decisions/`.

| ADR | Status | Decision |
|---|---|---|
| [0001](0001-adopt-agent-skills-with-a-human-orchestrator.md) | Accepted | Use the agent-skills pack. The human runs the lifecycle. |
| [0002](0002-store-product-context-in-the-repo.md) | Accepted | Specs, plans, ADRs, how-tos, and postmortems live in `context/`. |
| [0003](0003-start-with-a-rails-api.md) | Accepted | First runtime is a Rails API. Clients come later. |
| [0004](0004-the-product-is-sokong.md) | Accepted | The product is Sokong, assessed with Mara. The feature catalog is not a set of PRDs. |
| [0005](0005-nuxt-web-and-flutter-mobile.md) | Accepted | Web is Nuxt. Mobile is Flutter. Neither client is scaffolded yet. |
| [0006](0006-clients-are-localizable-english-first.md) | Accepted | Both clients are localizable. The first locale is English. |
| [0007](0007-build-loop-after-plan-approval.md) | Accepted | After plan approval, one fresh session per slice runs implement, review, and fix until a spec change or the loop is ready to merge. |
| [0008](0008-clean-build-loop-merges.md) | Accepted | A clean ready hop merges the pull request with a merge commit. |

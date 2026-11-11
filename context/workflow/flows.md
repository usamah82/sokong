# Feature flows

How a feature moves through sessions, status, and git. The gates are in [operating-model.md](operating-model.md) and `.cursor/skills/repo-workflow/SKILL.md`. The paste-in prompts are in [prompts.md](prompts.md). The task loop is [ADR-0007](../decisions/0007-run-the-task-loop-without-per-task-gates.md).

The human starts interview, spec, design, and plan. After `plan-approved`, one implementer runs every remaining task.

## Sessions through plan approval

`idea-refine` is optional. It writes notes in `intent.md` until the human picks a direction. Status stays `interviewing`.

Design runs only when `spec.md` describes a screen. It writes `design.md`, `design/preview.html`, and 390px screenshots. A picture that changes behavior is written back into `spec.md` in that same session. The human accepts the screenshots, then approves the spec. Status stays `spec-draft` until that approval.

A plan with more than one task stops for approval. A single small task may be implemented in a later turn of the same session only when the spec is already approved and the human asked to build it.

```mermaid
flowchart TD
  idea["Idea: catalog row or a human"] --> interview["Interview session<br/>writes intent.md<br/>status: interviewing"]
  refine["Optional idea-refine<br/>notes in intent.md"] -.-> interview
  interview --> confirmIntent{"Human confirms<br/>intent.md?"}
  confirmIntent -->|send back| interview
  confirmIntent -->|"status: intent-confirmed"| spec["Spec session<br/>writes spec.md<br/>status: spec-draft"]
  spec --> hasScreen{"Spec has a screen?"}
  hasScreen -->|yes| design["Design session<br/>design.md, preview.html,<br/>390px screenshots"]
  design --> acceptScreens{"Human accepts<br/>the screenshots?"}
  acceptScreens -->|send back| design
  acceptScreens -->|accepted| approveSpec{"Human approves<br/>the spec?"}
  hasScreen -->|no| approveSpec
  approveSpec -->|send back| spec
  approveSpec -->|"status: spec-approved"| plan["Plan session<br/>writes plan.md and tasks.md<br/>status: planning"]
  plan --> manyTasks{"More than one task?"}
  manyTasks -->|yes| approvePlan{"Human approves<br/>the plan?"}
  approvePlan -->|send back| plan
  approvePlan -->|"status: plan-approved"| build["Task loop"]
  manyTasks -->|"one task, and the human<br/>already asked to build it"| build
```

## Status

Set `Status` in the feature `README.md` to one of these. `parked` is allowed from any state, with a reason in that README.

Only a human sets `intent-confirmed`, `spec-approved`, `plan-approved`, or `done`. An agent may set `spec-draft`, `planning`, `implementing`, and `in-review`.

`implementing` covers the whole task loop, including task pull requests and their merges. `in-review` means the loop stopped for the human. The README says which of the three stops it was: the spec or the task would have to change, the same act-on finding survived one fix attempt, or no tasks remain.

```mermaid
stateDiagram-v2
  [*] --> interviewing
  interviewing --> intentConfirmed: human confirms intent.md
  intentConfirmed --> specDraft: agent writes spec.md
  specDraft --> specDraft: design, when the spec has a screen
  specDraft --> specApproved: human approves spec and any screens
  specApproved --> planning: agent writes plan.md and tasks.md
  planning --> planApproved: human approves the plan
  planApproved --> implementing: human starts the implementer once
  implementing --> implementing: task merged into the feature branch, tasks remain
  implementing --> inReview: loop stops for the human
  inReview --> implementing: human resolves a spec change and says continue
  inReview --> done: human has merged the feature branch to main
  done --> [*]

  state "intent-confirmed" as intentConfirmed
  state "spec-draft" as specDraft
  state "spec-approved" as specApproved
  state "plan-approved" as planApproved
  state "in-review" as inReview
```

`parked` can be entered from any state above. The README says why.

## One task, one pull request

The feature branch is `feature/<slug>`. Enrolment's is `feature/enrolment`, still ahead of `main`. Each task is a short-lived branch and one pull request into that feature branch. The implementer opens it, runs the review loop below, and merges it. Pull requests [#7](https://github.com/usamah82/sokong/pull/7) and [#8](https://github.com/usamah82/sokong/pull/8) merged into `feature/enrolment`. [#4](https://github.com/usamah82/sokong/pull/4) and [#5](https://github.com/usamah82/sokong/pull/5) merged into `cursor/record-product-answers`; `feature/enrolment` continues that line.

The human merges `feature/<slug>` into `main` after the last task. A merge to `main` still leaves production deploy as its own request. Hosting is undecided.

A checkpoint in `tasks.md` is checked after the tasks above it are on the feature branch. It does not get a pull request. A failed check that stays inside the spec is a commit on the feature branch. A failed check that needs a spec change stops the loop.

A typo, a failing test for already-accepted behavior, or a dependency bump does not need a feature folder. That change names the existing spec or ADR and can target `main`. Dependabot pull requests target `main`.

```mermaid
gitGraph
  commit id: "main"
  branch feature_slug
  checkout feature_slug
  commit id: "intent_spec_plan"
  branch task_a
  checkout task_a
  commit id: "task_a"
  checkout feature_slug
  merge task_a id: "implementer_merges" tag: "after_review"
  branch task_b
  checkout task_b
  commit id: "task_b"
  checkout feature_slug
  merge task_b id: "next_task"
  checkout main
  merge feature_slug id: "feature_into_main" tag: "human"
```

Tasks run one at a time, in `tasks.md` order. A note in `plan.md` that two tasks can run in either order does not start a second implementer.

## Review inside the task

The implementer follows `incremental-implementation` and `test-driven-development`, runs `bin/ci`, and opens the pull request. It then spawns `code-reviewer`. That persona reads `spec.md` and the diff, comments on the pull request, and does not edit the branch.

The implementer acts on Critical and Required from `code-reviewer`. It leaves Optional and Nit. When that review asks for another pass, the implementer spawns the named persona and acts on Critical, High, and Medium, leaving Low:

- `security-auditor` when the diff needs a security pass
- `test-engineer` when coverage is short
- `web-performance-auditor` when performance needs a pass

After the fixes, it spawns `code-reviewer` once more. It merges the task pull request when that pass has nothing left in the act-on bands and `bin/ci` is green. It checks the task and takes the next one. Status stays `implementing`.

It stops, sets `in-review`, and writes the reason in the feature README when:

- a finding can be fixed only by changing `spec.md` or that task's acceptance
- the same act-on finding is still open after one fix attempt
- no unchecked tasks remain

On the last of those, the human merges the feature branch to `main` and sets `done`.

```mermaid
sequenceDiagram
  actor Human
  participant Impl as Implementer
  participant PR as Task pull request
  participant Review as code-reviewer
  participant Extra as security, test, or performance

  Human->>Impl: Status is plan-approved. Run once.
  loop Each unchecked task
    Impl->>PR: Implement, bin/ci, open PR into the feature branch
    Impl->>Review: Spawn with the spec path and the diff
    Review->>PR: Comment. No edits.
    alt Fix would change the spec or the task
      Impl->>Human: Stop. Status in-review.
    else Findings stay inside the spec
      Impl->>Impl: Apply the act-on bands
      opt Review asked for another persona
        Impl->>Extra: Spawn that persona
        Extra->>PR: Comment. No edits.
        Impl->>Impl: Apply Critical, High, and Medium
      end
      Impl->>Review: Spawn again
      Review->>PR: Comment
      Impl->>PR: Merge into the feature branch when the act-on list is clear and bin/ci is green
    end
  end
  Impl->>Human: No tasks left. Merge the feature branch to main.
```

A local SDK agent for this loop uses `Agent.create` with `local: { cwd, settingSources: ["project"] }` and a model id. The personas in `.cursor/agents/*.md` are the subagents. The parent spawns them with the Agent tool, so the `task` tool stays allowed. Cloud `autoCreatePR` targets the default base, which is the wrong base for these pull requests. The Run prompt is the way to start the loop. A wrapper script is not in the repo.

## What stays a separate session

| Hop | Session writes | Then stop |
|---|---|---|
| Interview | `intent.md` | Human confirms |
| Spec | `spec.md` | Human approves, after design when there is a screen |
| Plan | `plan.md`, `tasks.md` | Human approves when more than one task remains |
| Run | Every remaining task, merged into the feature branch | A spec change, a stuck finding, or no tasks left |
| Feature branch to `main` | — | Human merges, then sets `done` |
| Deploy | — | Human asks, after an ADR names a host |

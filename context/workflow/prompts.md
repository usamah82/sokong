# Session prompts

Start a new agent session for each block. Paste the prompt. Fill `<slug>` and `<idea>`. Do not ask the same session to continue into the next phase.

The agent should follow `repo-workflow` without being reminded. Naming the upstream skill in the prompt keeps it from drifting.

## Interview

```
Interview me about this idea: <idea>

Follow the interview-me skill, one question at a time.
Create context/requirements/features/<slug>/ from the template.
Write your confirmed understanding only after I confirm it, in intent.md.
Set status to interviewing until I confirm, then stop.
Do not write a spec or code.
```

## Spec

```
Write the spec for context/requirements/features/<slug>/.

Follow spec-driven-development. Read intent.md first.
Write spec.md using the headings already in the template.
Set status to spec-draft and stop for my approval.
Do not plan and do not write code.
```

## Design

```
Design the screens in context/requirements/features/<slug>/spec.md.

Follow frontend-ui-engineering for the screen contract.
Read spec.md. Use its English copy as written.
If the spec has no screen, stop and say so.
Write design.md in that folder: each screen's job, primary action,
required states, and the phone-width rule.
Build a static review page at context/requirements/features/<slug>/design/preview.html.
Screenshot it at 390px wide and save the images in that design folder.
If a picture disagrees with the spec, update spec.md and say what changed.
Status stays spec-draft.
Do not plan, do not scaffold web/, and do not write API code.
```

## Plan

```
Plan context/requirements/features/<slug>/.

The spec is approved. Follow planning-and-task-breakdown.
Write plan.md and tasks.md in that folder.
Set status to planning and stop for my approval if more than one task remains.
Do not write code unless I already asked you to build a single task.
```

## Implement

```
Implement the next unchecked task in context/requirements/features/<slug>/tasks.md.

Follow incremental-implementation and test-driven-development.
Follow api-and-interface-design if the task changes HTTP.
Status must already be plan-approved or implementing. If it is not, stop.
Run bin/ci from the repository root before you finish.
Update the task checkbox and set status to in-review when the pull request is open.
Do not review your own change as if you were a second agent.
```

## Review

```
Review the open pull request for context/requirements/features/<slug>/.

Read .cursor/agents/code-reviewer.md and follow code-review-and-quality.
Read spec.md and the diff. Do not read the implementation chat.
Report findings. Do not change the code unless I ask you to fix a finding.
If the change touches auth, input, or data, say whether a security-auditor pass is needed.
```

## Security

```
Audit the open pull request for context/requirements/features/<slug>/.

Read .cursor/agents/security-auditor.md and follow security-and-hardening.
Report only. Do not change the code unless I ask you to fix a finding.
```

## Tests

```
Look for missing tests in the open pull request for context/requirements/features/<slug>/.

Read .cursor/agents/test-engineer.md and follow test-driven-development.
The testing reference uses JavaScript examples. Apply the principles to Rails integration tests.
Report gaps. Add tests only if I ask you to.
```

## Fix a red gate

```
bin/ci is failing. Follow debugging-and-error-recovery.
Reproduce, localize, reduce, fix, and add a guard test.
Do not weaken a check to make the command green.
```

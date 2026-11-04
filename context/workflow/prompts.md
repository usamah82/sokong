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
Set status to planning and stop for my approval.
Do not write code. The build loop starts in a new session after I set plan-approved.
```

## Continue the build loop

Paste this into a new chat to start the first hop, or to recover a hop whose `Claim` is `taken`. After that, the Sokong build loop automation starts each later hop when the pull request is pushed, when its checks finish, or when it merges. The same line is the whole instruction. ADR-0007. The procedure is the build loop in `repo-workflow`.

```
Continue the build loop for context/requirements/features/<slug>/.

Follow repo-workflow. Do the one action in handoff.md and stop.
If handoff.md is missing and status is plan-approved or implementing,
the action is implement for the next unchecked task.
If Claim is taken, stop and say the last hop is unfinished.
If status is spec-stop or done, stop.
If status is in-review, follow the merge section in repo-workflow and stop.
Do not start the next hop. Do not spawn an agent.
```

A dead hop leaves `Claim: taken`. The recovery line, in a new chat, is: take over the claimed hop for `context/requirements/features/<slug>/` and finish that one action.

## Security

An extra pass, only when you ask. The build-loop review already reads this persona when the diff touches auth, input, or stored data.

```
Audit the open pull request for context/requirements/features/<slug>/.

Read .cursor/agents/security-auditor.md and follow security-and-hardening.
Report only. Do not change the code unless I ask you to fix a finding.
```

## Tests

An extra pass, only when you ask. The build-loop review already files missing tests of specified behavior as findings.

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

# Session prompts

Interview, spec, design, and plan are separate sessions. Paste the prompt. Fill `<slug>` and `<idea>`. Do not ask one of those sessions to continue into the next phase. The diagrams are in [flows.md](flows.md).

After you set `plan-approved`, paste Run once. That session works every remaining task. A GitHub or CI wake is still that session. ADR-0007 is the rule.

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

## Run

```
Run the remaining tasks in context/requirements/features/<slug>/.

Follow ADR-0007. Follow incremental-implementation and test-driven-development.
Follow api-and-interface-design if a task changes HTTP.
Status must be plan-approved or implementing. If it is in-review, tasks remain,
and the README does not name a spec or task change waiting on me, set implementing
and continue. Otherwise stop.

Set status to implementing. Work tasks in order, one at a time.
The feature branch is feature/<slug>. Create it from main if it does not exist.
For each unchecked task, branch from the feature branch, implement it, run bin/ci
from the repository root, and open a pull request into feature/<slug>.

Spawn code-reviewer on that pull request. Give it the spec path and the diff.
It comments on the pull request and does not edit the branch.
Act on Critical and Required. Leave Optional and Nit.
Spawn security-auditor when the review says the diff needs a security pass.
Spawn test-engineer when a review says coverage is short.
Spawn web-performance-auditor when a review says performance needs a pass.
Those three comment and do not edit. Act on Critical, High, and Medium. Leave Low.
Use the matching brief below as their prompt. They do not spawn anyone.

Spawn code-reviewer again after the fixes. Merge the pull request into the
feature branch when the act-on list is clear and bin/ci is green. Check the task.
If the same act-on finding is still open after one fix attempt, or a fix would
change spec.md or the task's acceptance, stop. Set in-review and write the reason
in the feature README. Do not edit the spec.

A checkpoint is checked after the tasks above it are merged. No pull request
for the checkpoint. A failure inside the spec is a commit on the feature branch.
A failure that needs a spec change stops the loop.

A GitHub or CI notification is not a stop. Waiting for review or CI may end the
turn. On the wake, check tasks.md. If an unchecked task remains and the feature
README does not name a spec or task change waiting on me, start that task before
ending the turn. Stop only for the two stops in ADR-0007.

When no unchecked tasks remain, set in-review and stop. I will merge
feature/<slug> into main.
Do not merge to main. Do not deploy.
```

The briefs below are what Run gives each persona. A persona comments on the pull request and does not edit the branch.

## Review brief

```
Review the open task pull request for context/requirements/features/<slug>/.

You are the code-reviewer persona. Follow code-review-and-quality.
Read spec.md and the diff. Do not read the implementation transcript.
Comment on the pull request. Do not change the branch.
Say whether the diff needs a security-auditor pass, a test-engineer pass,
or a web-performance-auditor pass.
```

## Security brief

```
Audit the open task pull request for context/requirements/features/<slug>/.

You are the security-auditor persona. Follow security-and-hardening.
Comment on the pull request. Do not change the branch.
```

## Tests brief

```
Look for missing tests in the open task pull request for context/requirements/features/<slug>/.

You are the test-engineer persona. Follow test-driven-development.
The testing reference uses JavaScript examples. Apply the principles to Rails integration tests.
Comment on the pull request. Report gaps. Do not add tests and do not change the branch.
```

## Performance brief

```
Audit performance for the open task pull request for context/requirements/features/<slug>/.

You are the web-performance-auditor persona. Follow performance-optimization.
Comment on the pull request. Do not change the branch.
Tag unmeasured findings as potential impact.
```

## Fix a red gate

```
bin/ci is failing. Follow debugging-and-error-recovery.
Reproduce, localize, reduce, fix, and add a guard test.
Do not weaken a check to make the command green.
```

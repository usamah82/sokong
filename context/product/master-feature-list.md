# Master feature list

Catalog only. No row is the spec. The enrolment feature has an approved spec at `context/requirements/features/enrolment/`. Status is `done`. A spec starts when a human names the feature and the questions that block it are answered in [open-questions.md](open-questions.md).

"Deck" means the behavior is in [sokong-and-mara.pdf](sokong-and-mara.pdf). "Gap" means the deck requires it, or names it as a loose end, and does not describe it as a product behavior. Concepts are in [concepts.md](concepts.md).

The proposed first cluster, not an approval, is the record a phone enrolment needs: F01, F02, F03, F04, F05. The questions that blocked it are answered. Assessment (F08) is a separate PRD, and its questions are answered too.

F24 is deferred. The share counts every family in the locality, and Sokong only tracks families that need support, so the other features do not wait on it. F36 is the ownership question Q2 set aside. F37 is contesting a checkbox, which Q5 set aside. The first locale is English, and both clients are localizable (Q15, ADR-0006).

On 2026-11-16 Usamah kept the verification interview on the ideal first visit. That interview is F06 and F07, in `requirements/features/verification-visit/`. He set it to `intent-confirmed` on 2026-11-17. Duplicate enrolments and their reconciliation are F38, and F38 waits for its own interview.

## A. Place and people

| ID | Feature | What someone can do | Source | Blocked by |
|---|---|---|---|---|
| F01 | Localities | Create the boundary the work happens inside, and see which community it is. The boundary is the one the community workers choose, from a housing block up to a district. | Deck | — |
| F02 | Accounts and roles | Sign in as a community member, worker, benefactor, facilitator, planner, or a person in a family. See only what that role may see. A family can see its own four checkboxes. The first operator is the community worker. Hosting is not decided. | Deck | — |
| F03 | Family unit record | Record who is in the unit, how they are related, how to reach them, and where they stay, including a missing address or papers. A person can move from the unit they were born into, to one they start, to one they retire into. A unit may be one person, or an institution such as an orphanage. | Deck | — |

## B. Getting into the program

| ID | Feature | What someone can do | Source | Blocked by |
|---|---|---|---|---|
| F04 | Enrolment | A family enrols itself, or a community member enrols them and leaves their own contact. The form is short: who is in the unit, the needs that count for this locality and this family, location, phone if there is one. On-behalf data needed to help is stored, sourced, and shown to community workers. No office and no early rejection. | Deck | — |
| F05 | Enrolment progress | The person who submitted can see who has looked, what they said, and when the first visit is. | Deck | — |
| F06 | Verification visit | A worker schedules a face-to-face visit, aims for within a week, records the basket taken, the consent, and the identity check, and writes the story the form could not hold. Facts the worker has seen and verified outrank the enrolment. | Deck | — |
| F07 | Qualification | Mark the family qualified or disqualified after the verification visit. A qualified family can move into Empowerment. A disqualified family stays on record and is not promoted. | Deck | — |
| F38 | Duplicate enrolments | Flag a later enrolment that looks like an earlier one and link the two. The likeness is a loose fingerprint of the enrolment details. If the earlier enrolment is qualified, mark the later one duplicated and leave the worker nothing to do. If the earlier one is disqualified, the worker still verifies the later enrolment and can qualify or disqualify it. | Usamah, 2026-11-16 | F07 |

## C. The Mara record

| ID | Feature | What someone can do | Source | Blocked by |
|---|---|---|---|---|
| F08 | Assessment | Record the four boxes in priority order, the generation word, the wealth word, and the status derived in Q4. The community worker checks the boxes. The family can see them. Clearing good family unit also clears dependable generation. Clearing basic necessities also clears accumulated wealth, unless the family keeps the wealth and goes without necessities. Keep every past assessment. | Deck | — |
| F09 | Story | Append the path: careers, school, births, assets, help already given, decisions the family made. | Deck | — |
| F10 | Starting point, opportunities, calamities | Record the external facts separately from status, so a fall is not stored as a moral failure. | Deck | — |
| F11 | Direction | Show whether the latest status is a step up, a step down, or no move, not only the current label. | Deck | — |

## D. Staying with the family

| ID | Feature | What someone can do | Source | Blocked by |
|---|---|---|---|---|
| F12 | Visit rhythm | Plan the next visit at or before three months, and never allow a planned gap past six months. Record an unscheduled visit. | Deck | — |
| F13 | Events | Record an event the family discloses, and an event a worker learns from outside and types in. Mark an event that hits the whole locality. | Deck, and a loose end for disasters | — |
| F14 | Reassessment | After help, record whether it worked, why, and the next step, then update the boxes. | Deck | — |
| F15 | Graduation and dropout | Close the case as thriving when all four boxes are checked, or as dropped out, with the reason. Keep the history. When the unit dissolves, point at the next units. | Deck | — |
| F16 | Worker caseload | Show a worker's families, the visits that are late, and the registrations still waiting. Show a leader when the workers are losing families. The first operator is the community worker. | Deck | — |

## E. Help

| ID | Feature | What someone can do | Source | Blocked by |
|---|---|---|---|---|
| F17 | Needs | Publish what this family still lacks, against the four boxes, without exposing the rest of the story. The family can already see its own boxes. | Deck | — |
| F18 | Offers | A benefactor offers something specific: money, food, materials, time, a skill, a pro bono service. The offer can be matched only after a community worker for that locality has verified the benefactor. | Deck | — |
| F19 | Match | Connect an offer to a qualified family in a locality, and show when that family already received the same kind of help, so help is not repeated and can be spread. | Deck | — |
| F20 | Facilitator handoff | A facilitator sees qualified families a worker has named, pools offers, and records what was passed on. The facilitator is verified by the locality's community workers first. | Deck | — |
| F21 | Suggested next box | Given the assessment, name the earliest unchecked box and the kinds of help the deck associates with it. A person still chooses the help. | Deck | — |
| F22 | Family request | A family already in the program asks for a particular kind of help, in one place. The request is recorded. The help itself is given outside the app. | Loose end, and the "request for help" scene | — |

## F. The locality, seen from above

| ID | Feature | What someone can do | Source | Blocked by |
|---|---|---|---|---|
| F23 | Caseload outcomes | For families inside Sokong, show counts of qualified, struggling, deteriorating, thriving, graduated, and dropped out, and how those counts moved. | Deck | — |
| F24 | Nation measure | Report the share of thriving family units in a locality, including families who are not in the program. Deferred. Sokong's caseload cannot compute it. | Deck | — |
| F25 | Planner evidence | Tie a claimed budget or a built facility to the families and the help the record actually shows. This is the caseload, not the locality-wide percentage. | Deck | — |
| F26 | Scarce help | When qualified families outnumber offers, highlight units that have gone without help. Community workers and facilitators set the order. Record the order and who set it. | Loose end | — |

## G. Trust

| ID | Feature | What someone can do | Source | Blocked by |
|---|---|---|---|---|
| F27 | Consent and retention | Record who consented, to what, and when. On-behalf data needed to help is stored before that consent, with its source, for community workers. Keep dropped and disqualified records only as far as the privacy rule that gets written down. A family can ask what is held. | Deck names PDPA and GDPR as open | — |
| F28 | Partner verification | The community workers of a locality check a benefactor or a facilitator before their offer can be matched, and keep a record of a fake charity. | Loose end | — |
| F29 | Likely duplicates | Keep one list of family units across organizations. When a new registration looks like an existing unit, tell the organizations that help may overlap so it can be spread. A later Sokong enrolment that looks like an earlier one is F38. | Loose end | — |
| F30 | Notifications | Tell the worker, the person who enrolled, and the family when a registration is seen, a visit is set, or a visit is late. | Deck, the Sarah story | — |

## H. Held until you say otherwise

| ID | Feature | Why it is held |
|---|---|---|
| F31 | People outside a family unit | Answered by Q11 and folded into F03. A unit of one person, or a unit such as an orphanage. Not a separate record. |
| F32 | Prevention before a family is deteriorating | Out of this app (Q14). |
| F33 | Teaching the three values | Out of this app (Q14). Curriculum, marriage courses, counseling as a national program, and a campaign. |
| F34 | Live feeds from agencies | Not in the first version (Q10). A worker types the event under F13. Q3 still wants a systematic feed later, such as a government disbursement. |
| F35 | Poor connectivity on a visit | Not in the deck. Field visits in the story happen in low-cost housing. Raise it if the first locality cannot assume a signal. |
| F36 | Local custody and a government query | Q2 set this aside so the first version can be usable. The community owns the locality's data and organizes the work. A government queries up to a limit still to be defined, and assists as a benefactor. |
| F37 | Contest a checkbox | Q5. The family can see the four boxes. A later feature can let them contest a check and resolve it with the community worker. The first version does not. |

## What is not a feature

Changing a school curriculum, running a mass-media campaign, paying benefits inside the app, scoring a person's moral worth, and reforming a political system. The last slide of the PDF is the author's motive. It is not a requirement.

## Dependency sketch

```
F01 Localities
  └─ F02 Accounts
       └─ F03 Family record
            ├─ F04 Enrolment ── F05 Progress
            │        └─ F06 Visit ── F07 Qualification ── F38 Duplicate enrolments
            │                 └─ F09 Story
            │                 └─ F08 Assessment ── F11 Direction
            │                          └─ F14 Reassessment ── F15 Graduation
            └─ F10 External facts
F12 Visit rhythm and F16 Caseload sit on F06 and F03
F17 Needs, F18 Offers, F19 Match, F20 Handoff sit on F07 and F08
F23 Caseload outcomes sit on F08 and F15
F24 Nation measure is deferred. It counts families Sokong does not track, and it is not required to enrol the first family
F36 Local custody waits until a human asks for that PRD
F37 Contesting a checkbox waits until a human asks for that PRD
F38 Duplicate enrolments waits for its own interview. It needs the qualified and disqualified marks from F07
```

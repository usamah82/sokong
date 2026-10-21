# Master feature list

Catalog only. No row is a PRD, and none has a folder under `context/requirements/features/`. A PRD starts when a human names the feature and the questions that block it are answered in [open-questions.md](open-questions.md).

"Deck" means the behavior is in [sokong-and-mara.pdf](sokong-and-mara.pdf). "Gap" means the deck requires it, or names it as a loose end, and does not describe it as a product behavior. Concepts are in [concepts.md](concepts.md).

The proposed first cluster, not an approval, is the record a phone enrolment needs: F01, F02, F03, F04, F05. It is blocked by Q2, Q6, and Q8. Assessment (F08) is a separate PRD, blocked by Q4 and Q5.

## A. Place and people

| ID | Feature | What someone can do | Source | Blocked by |
|---|---|---|---|---|
| F01 | Localities | Create the boundary the work happens inside, and see which community it is. | Deck | Q2, Q6 |
| F02 | Accounts and roles | Sign in as a community member, worker, benefactor, facilitator, planner, or a person in a family. See only what that role may see. | Deck | Q2, Q5, Q8 |
| F03 | Family unit record | Record who is in the unit, how they are related, how to reach them, and where they stay, including a missing address or papers. A person can move from the unit they were born into, to one they start, to one they retire into. | Deck | Q6, Q11 |

## B. Getting into the program

| ID | Feature | What someone can do | Source | Blocked by |
|---|---|---|---|---|
| F04 | Enrolment | A family enrols itself, or a community member enrols them and leaves their own contact. The form is short: who is in the unit, basic needs, location, phone if there is one. No office and no early rejection. | Deck | Q7, Q8 |
| F05 | Enrolment progress | The person who submitted can see who has looked, what they said, and when the first visit is. | Deck | Q8 |
| F06 | Verification visit | A worker schedules a face-to-face visit, aims for within a week, records the basket taken, the consent, and the identity check, and writes the story the form could not hold. | Deck | Q3, Q8 |
| F07 | Qualification and the scam record | Mark the family qualified or disqualified. Keep a disqualified record and match a later enrolment against basic details and contact so a scam cannot re-enter. | Deck | Q9 |

## C. The Mara record

| ID | Feature | What someone can do | Source | Blocked by |
|---|---|---|---|---|
| F08 | Assessment | Record the four boxes in priority order, the generation word, the wealth word, and the status. Keep every past assessment. | Deck | Q4, Q5, Q7 |
| F09 | Story | Append the path: careers, school, births, assets, help already given, decisions the family made. | Deck | — |
| F10 | Starting point, opportunities, calamities | Record the external facts separately from status, so a fall is not stored as a moral failure. | Deck | — |
| F11 | Direction | Show whether the latest status is a step up, a step down, or no move, not only the current label. | Deck | Q4 |

## D. Staying with the family

| ID | Feature | What someone can do | Source | Blocked by |
|---|---|---|---|---|
| F12 | Visit rhythm | Plan the next visit at or before three months, and never allow a planned gap past six months. Record an unscheduled visit. | Deck | — |
| F13 | Events | Record an event the family discloses, and an event a worker learns from outside. Mark an event that hits the whole locality. | Deck, and a loose end for disasters | Q10 |
| F14 | Reassessment | After help, record whether it worked, why, and the next step, then update the boxes. | Deck | Q4 |
| F15 | Graduation and dropout | Close the case as thriving when all four boxes are checked, or as dropped out, with the reason. Keep the history. When the unit dissolves, point at the next units. | Deck | Q4 |
| F16 | Worker caseload | Show a worker's families, the visits that are late, and the registrations still waiting. Show a leader when the workers are losing families. | Deck | Q2 |

## E. Help

| ID | Feature | What someone can do | Source | Blocked by |
|---|---|---|---|---|
| F17 | Needs | Publish what this family still lacks, against the four boxes, without exposing the rest of the story. | Deck | Q3, Q5, Q9 |
| F18 | Offers | A benefactor offers something specific: money, food, materials, time, a skill, a pro bono service. | Deck | Q3, Q13 |
| F19 | Match | Connect an offer to a qualified family in a locality, and show when that family already received the same kind of help. | Deck | Q9, Q12, Q13 |
| F20 | Facilitator handoff | A facilitator sees qualified families a worker has named, pools offers, and records what was passed on. | Deck | Q9 |
| F21 | Suggested next box | Given the assessment, name the earliest unchecked box and the kinds of help the deck associates with it. A person still chooses the help. | Deck | Q3, Q4, Q12 |
| F22 | Family request | A family already in the program asks for a particular kind of help, in one place. | Loose end, and the "request for help" scene | Q3 |

## F. The locality, seen from above

| ID | Feature | What someone can do | Source | Blocked by |
|---|---|---|---|---|
| F23 | Caseload outcomes | For families inside Sokong, show counts of qualified, struggling, deteriorating, thriving, graduated, and dropped out, and how those counts moved. | Deck | Q4 |
| F24 | Nation measure | Report the share of thriving family units in a locality, including families who are not in the program. | Deck | Q1, Q4 |
| F25 | Planner evidence | Tie a claimed budget or a built facility to the families and the help the record actually shows. | Deck | Q1, Q2 |
| F26 | Scarce help | When qualified families outnumber offers, record the order and who set it. | Loose end | Q12 |

## G. Trust

| ID | Feature | What someone can do | Source | Blocked by |
|---|---|---|---|---|
| F27 | Consent and retention | Record who consented, to what, and when. Keep dropped and disqualified records only as far as the privacy rule that gets written down. A family can ask what is held. | Deck names PDPA and GDPR as open | Q8 |
| F28 | Partner verification | Check a benefactor or a facilitator before their offer can be matched, and keep a record of a fake charity. | Loose end | Q13 |
| F29 | Separate books | Let an organization keep its own recipient list and still coordinate, if it will not join a shared list. | Loose end | Q9 |
| F30 | Notifications | Tell the worker, the person who enrolled, and the family when a registration is seen, a visit is set, or a visit is late. | Deck, the Sarah story | Q8 |

## H. Held until you say otherwise

| ID | Feature | Why it is held |
|---|---|---|
| F31 | People outside a family unit | Q11. The loose ends name them. The body of the deck says the unit of the program is the family. |
| F32 | Prevention before a family is deteriorating | Q14. Named as unfinished thinking, with no mechanism. |
| F33 | Teaching the three values | Q14. Curriculum, marriage courses, counseling as a national program, and a campaign. Likely a movement, not this app. |
| F34 | Live feeds from agencies | Q10. Named as event sources. A person can type an event under F13 without a feed. |
| F35 | Poor connectivity on a visit | Not in the deck. Field visits in the story happen in low-cost housing. Raise it if the first locality cannot assume a signal. |

## What is not a feature

Changing a school curriculum, running a mass-media campaign, paying benefits inside the app, scoring a person's moral worth, and reforming a political system. The last slide of the PDF is the author's motive. It is not a requirement.

## Dependency sketch

```
F01 Localities
  └─ F02 Accounts
       └─ F03 Family record
            ├─ F04 Enrolment ── F05 Progress
            │        └─ F06 Visit ── F07 Qualification
            │                 └─ F09 Story
            │                 └─ F08 Assessment ── F11 Direction
            │                          └─ F14 Reassessment ── F15 Graduation
            └─ F10 External facts
F12 Visit rhythm and F16 Caseload sit on F06 and F03
F17 Needs, F18 Offers, F19 Match, F20 Handoff sit on F07 and F08
F23 Caseload outcomes sit on F08 and F15
F24 Nation measure sits on Q1, and is not required to enrol the first family
```

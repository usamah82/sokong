# Design

Review pictures for the verification visit. Usamah accepted the first screenshots and approved the spec on 2026-11-17. On 2026-11-18 he asked for a pre-visit section, document numbers, and the initial assessment in a post-visit section. These pictures match that revision. Sample names and the place "Block 4" are there so the layout can be judged. They are not default form values.

The worker case has Pre-visit, Verification Interview, and Post-visit. Submitter progress and the enrolments list gain the visit line and the outcome line. This pass uses the same paper, ink, and green button as the enrolment pictures.

## Visual language

Sokong has no palette yet. This pass uses a warm paper sheet, near-black text, and one dark green button. Corners are 4px. There is no gradient, no shadow, and no illustration.

| Token | Value |
|---|---|
| Paper | `#f3f0e8` |
| Sheet | `#fffcf7` |
| Ink | `#1c1915` |
| Muted | `#5c564c` |
| Line | `#d4cec3` |
| Accent | `#1e3a2f` |

Type is the system sans at 16px. The case title is 22px. Labels are 14px. Inputs and the stage buttons are at least 44px tall. Page padding is 16px, and the column is 390px wide.

The stage list is a vertical list. A stage name wraps inside the column. "Current", "Saved", and "Not saved" are words, so the open stage is not marked by color alone.

Patterns this screen rejects: a hero, a card grid, a horizontal stepper, purple, and placeholder copy in place of the spec's sentences.

## Phone width

Every picture is 390 CSS pixels wide. The page scrolls vertically. It does not scroll horizontally. Open `design/preview.html` and add `?screen=` with one of the names below.

## Screens

### Pre-visit

Job: set the visit time, record whether a basket is coming, and name the assigned workers, before the interview is available.

Primary action: Set visit.

The section heading is "Pre-visit". The time field is labeled "Visit time". A stored time keeps that label. "Bringing a basket" is a checkbox. "Assigned workers" starts with the signed-in worker's name. "Add a worker" adds another name.

States: no time yet; a value that is not a time.

Copy, as in the spec:

- "Aim for a visit within a week of the enrolment."
- "Set the visit before recording it."
- "Visit time is invalid"
- "Bringing a basket"
- "Assigned workers"
- "Add a worker"

Pictures: [set-visit.png](design/set-visit.png), [visit-invalid.png](design/visit-invalid.png).

### Visit time, then the interview

Job: show the stored pre-visit answers, say whether the visit is later than a week, and keep the six stages on screen.

Primary action: Change visit, until the family is marked. After that, the pre-visit answers are text.

The sample time `2026-11-24T01:00:00Z` is shown to a UTC+8 viewer as "24 November 2026 at 09:00". A later sample, "25 November 2026 at 09:00", also shows "This visit is later than a week after the enrolment."

The heading is "Verification Interview". The stages, in order, are "Who is here", "How the family formed", "A day in their life", "How they are together", "The house and the meals", and "What they need". The open stage shows "Current". A saved stage shows "Saved". The others show "Not saved". Post-visit sits below the interview and is not a stage in the list.

Pictures of the late time and the on-time interview: [visit-late.png](design/visit-late.png), [who-is-here.png](design/who-is-here.png).

### Who is here

Job: record everyone who lives here, guests who are not on that list, care for elderly parents, each person's identity, and any document numbers.

Primary action: Next. There is no Back. "Add a person" inserts a person who needs a name. An added person has "Remove". Farid is that person in the picture. The head shows "Head" and has no relationship choice. Every other person has "Relationship". "From where?" is hidden when the relationship is Child. "Absent" opens "Since when" and "Why". "Since when" is a date, `YYYY-MM-DD`. "Add a document" adds a document type and a number. Other opens "What document?". A document row has "Remove". Zero documents is allowed. After the people, Yes on a guest opens "Who, and why?" Yes on care for elderly parents opens "Who, and what do you do for them?"

The open person shows "Enrolment" above the name, the gender, and the phone. A bad phone stays on this stage. Identity is the choice Verified, Not verified, or No papers. The document numbers sit under that choice.

Copy:

- "The children are the people recorded here."
- "Full name"
- "Birth date"
- "Gender"
- "Phone"
- "Documents"
- "Document"
- "National ID"
- "Social security number"
- "Passport"
- "Birth certificate"
- "Other"
- "What document?"
- "Number"
- "Add a document"
- "From where?"
- "Relationship"
- "Head"
- "Spouse"
- "Child"
- "Parent"
- "Other"
- "Identity"
- "Verified"
- "Not verified"
- "No papers"
- "Absent"
- "Since when"
- "Why"
- "Does anyone else stay who is not in that list?"
- "Who, and why?"
- "Do you have to take care of elderly parents?"
- "Who, and what do you do for them?"
- "Yes"
- "No"
- "Enter a phone number, for example +60 12-345 6789."
- "Anything else they said"

Gender is Male, Female, or Unspecified. The sample head is Female. The absent picture opens Rahman, a spouse.

Pictures: [who-is-here.png](design/who-is-here.png), [who-absent.png](design/who-absent.png), [who-error.png](design/who-error.png).

### How the family formed

Job: write when this household started, and how.

Primary action: Next. Back returns to Who is here.

"When did this family start?" is a year. A value that is not a year from 1900 through the current year shows "Enter the year, for example 2008."

Copy:

- "When did this family start?"
- "How did it start?"
- "Enter the year, for example 2008."

Picture: [formation.png](design/formation.png).

### A day in their life

Job: ask one person at a time about work and school. Working and school are independent.

Primary action: Next.

"Are you working?" and "Are you in school?" are always on the screen, answered with "Yes" and "No". Yes on working opens the job, "Ringgit per month", previous jobs, and the work they want. "Any skills to highlight?" stays either way. Yes on school opens the three school questions. The enrolment fact sits above working, school, the job, and the monthly amount.

The working picture is Aminah, working, 800 ringgit a month, not in school. The school picture is Sarah, not working, in school.

Copy:

- "Are you working?"
- "Are you in school?"
- "What job?"
- "Ringgit per month"
- "Any previous jobs?"
- "Any skills to highlight?"
- "If you wish for a new job or income, what would that be?"
- "How is school going?"
- "Where is school?"
- "How do you get there?"

Pictures: [daily-life.png](design/daily-life.png), [daily-school.png](design/daily-school.png).

### How they are together

Job: write what the family said about life at home. The screen does not score a person.

Primary action: Next.

"How are the children at home?" is on this screen because Sarah's relationship is Child. It stays off when no person is a Child.

Copy:

- "Write what the family said."
- "What does a hard week look like here?"
- "When someone here needs help, who steps in?"
- "How are the children at home?"

Picture: [dynamics.png](design/dynamics.png).

### The house and the meals

Job: record the place, the rent, the utilities, safety, meals, and the basket.

Primary action: Next.

"This place" is one choice. Rent opens "Rent per month" and "Are you behind on payments?" Water and electricity stay Yes and No. "How many rooms do people sleep in?" is a number. No on "Is this place safe?" opens "What feels unsafe?" "How many meals a day?" is one choice. "Basket" is the last question before "Anything else they said".

The picture is Rent, behind on payments, one room, and not safe, so those follow-ups are visible.

Copy:

- "This place"
- "Own"
- "Rent"
- "Staying with someone"
- "Temporary"
- "Rent per month"
- "Are you behind on payments?"
- "Does it have water?"
- "Does it have electricity?"
- "How many rooms do people sleep in?"
- "Is this place safe?"
- "What feels unsafe?"
- "How many meals a day?"
- "3 a day"
- "2 a day"
- "1 a day"
- "Not every day"
- "Basket"
- "Yes"
- "No"

Picture: [house.png](design/house.png).

### What they need

Job: ask what would help most, and record consent.

Primary action: none. This is the last interview stage. Back returns to The house and the meals. Post-visit is the next section on the page.

The enrolment help sits above the question. The sample lists Food and School supplies. "The family does not consent" is selected, which blocks "Mark qualified" and still allows "Mark disqualified".

Copy:

- "Enrolment"
- "Food"
- "School supplies"
- "What do you need most?"
- "The family consents"
- "The family does not consent"

Picture: [needs.png](design/needs.png).

### Post-visit

Job: record Good family unit and Basic necessities, each with a gap, then mark the family.

Primary action: Mark qualified, or Mark disqualified.

The section heading is "Post-visit". It shows "Saved" or "Not saved". "Initial assessment" names the judgment. An unchecked box needs a gap. A checked box can leave the gap empty. One picture shows "Gap is required" and "The family has not consented" together. Another shows "The visit record is incomplete" when a stage has not been saved. Dependable generation and accumulated wealth are absent. The section is not in the stage list.

Copy:

- "Post-visit"
- "Initial assessment"
- "This is your judgment from the visit."
- "Integrity, action, and selflessness, for the family as a whole."
- "Good family unit"
- "Basic necessities"
- "Gap"
- "Gap is required"
- "The family has not consented"
- "The visit record is incomplete"
- "Mark qualified"
- "Mark disqualified"
- "Saved"
- "Not saved"

Pictures: [boxes.png](design/boxes.png), [boxes-gap.png](design/boxes-gap.png), [boxes-incomplete.png](design/boxes-incomplete.png).

### After the mark

Job: show the finished visit as text. The stage list stays. Set visit, Change visit, Add a worker, Back, Next, Add a person, Add a document, and both mark actions are gone. Pre-visit and Post-visit are text.

Primary action: open a stage from the list. The stage is text.

Copy:

- "This family is qualified."
- "This family is disqualified."

Pictures: [marked.png](design/marked.png), [marked-disqualified.png](design/marked-disqualified.png).

### Submitter progress

Job: show the visit time, and later the outcome, without the interview.

Primary action: Sign out.

States: nobody has looked and no visit is set; a look exists and no visit is set; a visit is set; the family is qualified.

Copy:

- "This case is in. No one has looked. No visit is set."
- "This case is in."
- "No visit is set."
- "A visit is set for 24 November 2026 at 09:00."
- "This family is qualified."

Pictures: [progress-quiet.png](design/progress-quiet.png), [progress-look.png](design/progress-look.png), [progress-visit.png](design/progress-visit.png), [progress-qualified.png](design/progress-qualified.png).

### Enrolments list

Job: let a person with many families, and a worker, see each visit and each outcome without opening the case.

Primary action: open a case. Sign out is the other action.

A row with no outcome has no outcome line. The same lines are used for the submitter and the worker.

Copy:

- "A visit is set for 24 November 2026 at 09:00."
- "This family is qualified."
- "No visit is set."

Picture: [cases.png](design/cases.png).

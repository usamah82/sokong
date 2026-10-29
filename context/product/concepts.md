# Sokong and Mara

Source: [sokong-and-mara.pdf](sokong-and-mara.pdf), 146 pages, stored 2026-10-21. That file is an introduction to an idea. It says itself that the framework and the program are "sort of" defined, and it ends with loose ends. This note is the working reading. Where the source uses two rules for the same word, the human answer in [open-questions.md](open-questions.md) is the one to follow. Nothing here is a PRD.

## The claim

A country needs good people. Good people carry three values: integrity, action, and selflessness. Integrity sets direction. Action keeps the movement going. Selflessness keeps people moving together. The source asks us not to obsess over synonyms. The short names are the ones to keep.

People do not become good because someone tells them to. They are born into a family unit, raised there, and as adults they spend most of their lives providing for a family unit. The family unit is the society unit this program focuses on. Communities, individuals, races, and classes are the wrong unit for this work.

The cycle the program wants:

Good family units produce good people, and those people start good family units.

The cycle it wants to interrupt:

Broken family units produce people who are more likely to be broken, and those people start broken family units.

Education matters, and it is not enough. Most of the reasons a child falls out of school sit outside the school, in the family unit.

## Mara, the measurement

Mara is a nation assessment. The question it wants a nation to be able to answer is: what share of family units are thriving, why, and what changed during a term of office.

It refuses to treat income, GDP, or a one-off aid headline as the measure of a family. A poor family can be good. A wealthy family can be broken. An atypical shape is not automatically broken: a single parent, a couple without children, grandparents raising grandchildren, or a blended family can be a good family unit. A complete set of typical members can still be a broken one.

### Internal and external

The three values are the internal factor. They are the family's hands and feet on the climb. They do not guarantee wealth, safety, or a happy ending. They make it more likely that the family will try to turn the right way, and will try to correct a wrong turn.

External factors, which the values do not control:

- Starting point. Education, inheritance, or an early burden of poverty.
- Opportunities. A better neighborhood, a scholarship, a real career, capital, peace.
- Calamities. Death, illness, job loss, accident, crime, disaster, war, or a decision that becomes a calamity.

Opportunities are rarer, and calamities more common, for families who are already struggling or deteriorating. Desperation can break a good family unit.

The source is wary of scoring a person's inner worth. Awareness, intention, and effort matter more than a grade of someone's character. Heads of the unit, usually the parents, are the people who must practice and champion the values. Every member does not need the same mix.

### The four boxes, in order

A family that wants to thrive aims at four things, in this order. Accumulated wealth is the least important of the four. A community worker checks the boxes. The family can always see their own four. Contesting a wrong check is later work, F37, and is not in the first version ([Q5](open-questions.md)).

1. Good family unit. The heads practice integrity, action, and selflessness. A community worker marks the box from face-to-face contact and from regular visits and chats. The bar is that the family as a whole, on average, is adopting the three values. Clearing this box also clears dependable generation.
2. Fulfilled basic needs. A roof and food are the examples the source names. The worked story also treats unpaid rent, utilities, and care for a disabled child as basic needs. There is no universal closed list. The locality sets what counts, and one family unit's needs can differ from another's ([Q7](open-questions.md)). Clearing this box also clears accumulated wealth, unless the family keeps the wealth and goes without necessities rather than sell optional possessions.
3. Dependable generation. The next generation can stand on their own and can be relied on as the next good people. Good education is the means the source names. Imprinting the three values by example comes before the certificate. By default this box cannot stay checked once good family unit is cleared.
4. Accumulated wealth. Income stays above expenses after basic needs, so the family can absorb a calamity, take an opportunity, retire, and give the next generation a head start. Wealth that is legitimate, earned, and used for the family. A dependable generation without wealth is better than wealth with a neglected generation. By default this box cannot stay checked once basic necessities are cleared. The exception is the family that keeps the wealth and goes without necessities.

### Status words

Status on screen comes from the four boxes. The generation-by-wealth table is the source's definition of the generation and wealth words. It does not set the status. That choice is [Q4](open-questions.md).

The rule in [Q4](open-questions.md):

- Deteriorating, whenever good family unit and basic necessities are not both checked.
- Struggling, when those two are both checked and the last two are not both checked.
- Thriving, when all four are checked.

Sarah at six months, with only basic needs checked, is Deteriorating. At a year and a half, with the first two checked, she is Struggling. At two years, with the first three checked, she is still Struggling. At seven years, with all four checked, she is Thriving.

The source table, kept so the generation and wealth words still have a meaning:

| Status word in the source | Generation | Wealth |
|---|---|---|
| Thriving | Dependable. The next generation can carry on and can carry others. | Accumulated. Excess after basic needs. |
| Struggling | Independent. They can stand alone, and may not be able to carry others. | Minimal. Little buffer. The next generation starts from scratch. |
| Deteriorating | Broken. The next generation still needs help, while the retiring generation will need them too. | Negative. Debt or a poverty trap. |

Current status is not the same thing as direction. A deteriorating family that is climbing toward struggling is turning the right way. A thriving family sliding toward struggling is turning the wrong way. Sitting still in deteriorating is not the right turn.

The path of one family unit is described as about 30 to 40 years, from formation to retirement. The far end of a good path is continuous legacy and generational wealth. Each family has its own route. The four boxes are the generalized route.

### What Mara is for

If the share of thriving family units can be shown, a leader can be asked what the share is, why, what they will do, and whether it rose while they were responsible. Grand announcements of investment or GDP do not answer that. The source calls this the cure for garbage-in, garbage-out politics.

The percentage counts every family unit in the locality, including families Sokong does not track ([Q1](open-questions.md)). Sokong tracks families that need support, so its database alone cannot produce the percentage. That percentage is not required for the features that run the program. F24 is the feature that would need the families outside Sokong, and it waits.

## Sokong, the program

Sokong uses Mara. It takes struggling and deteriorating family units and tries to graduate them as thriving ones. It is a funnel with two phases.

```
Enrolment (self, or reported by someone else)
  → verification visit
      → disqualified (record kept)
      → qualified
          → track and assist, for years
              → graduated (thriving)
              → dropped out (record kept within privacy limits)
```

### Verification

High volume, quick.

Anyone can enrol. Self-enrolment is preferred because it records consent. Someone else, a community member, may enrol a family and leave their own contact so a worker can follow up. Data entered on a family's behalf, such as by a teacher, is stored when it is needed to help, and it is available to the community workers who decide the next step. Each fact has a source. The strongest record is what the responsible community worker has seen and verified on the visit ([Q8](open-questions.md)). Enrolment asks for a family profile (who is in it, and basic needs), a location, and a phone number when there is one. It should be possible from a phone, without an office, a form, office hours, or an official who can reject it early. The person who enrolled should be able to see progress.

Qualification requires a face-to-face visit. The visit is there to build trust, bring a basket of basic necessities, take explicit consent and a verifiable identity when the family did not self-enrol, and fill in the story. The enrolment form is only the tip. The first visit in the story is usually within a week.

A family is qualified when they are struggling or deteriorating and the story checks out. A disqualified family, especially a scam, stays in the database so the same basic details and contact cannot be used to enrol again and collect help.

### Empowerment

Long. The source's simulation takes seven years, and it also shows a version where the family still comes apart. The result can sit in the next generation.

Two repeating activities:

Track. A worker stays in touch. A visit every quarter, and never a gap longer than six months, plus unscheduled visits when something happens. Show up, bring a basket, ask how they are. Listen for events the family discloses, and for events from outside (the source names school, hospital, police, court, tax, and social security). In the first version the worker types those outside events. A feed from an agency is later work ([Q10](open-questions.md)). Some events hit one family. Some hit a whole locality, such as a flood. Then reassess: what help was given, did it work, what is next, has the path become thriving.

Assist. Work the four boxes in order. Do not chase wealth while basic needs are open. Help is given by people and organizations. Whenever it is given, the app records it, so the same help is not given twice and help can move toward units that have not received it ([Q3](open-questions.md)). The family graduates when all four boxes are checked, which is the Thriving status.

A family drops out when they no longer want to be in the program, they cannot be reached, the workers lose them because the caseload won, or the heads retire and the unit dissolves into the next generation's units. Keep the record as far as privacy rules allow, so later work can be audited and improved.

The assistance examples in the source are counseling, alimony and enforcement, childcare, housing, utilities, food, water, electricity, a job match, retraining, business capital, an allowance for disability, school, a scholarship, a camp, a mentor. Those are treatments the community arranges. They are not described as features the software performs by itself.

### Who does what

| Role | Who | What they do |
|---|---|---|
| Community member | Anyone who lives in a locality | Notice a family that will not reach out. Enrol them. |
| Community worker | Community leaders, staff of a local representative office, social workers assigned to a locality | The long relationship. Visit, assess, say what is needed, work with facilitators, repeat. |
| Benefactor | A person or an organization with something to give: food, a clinic, money, time, tuition, materials, a pro bono service, a government agency | Offer a specific kind of help, inside or outside the locality. |
| Facilitator | NGOs, charities, people who pool help | They may not hold the resources. They collect from benefactors and, with workers, point the help at qualified families. |
| Nation planner | A local representative or a member of parliament | Champion the locality, bring resources, and be judged on whether thriving family units increased there. |
| Family unit | The people being supported | Enrol, consent, tell the story, take part. The source is plain that help fails when the family will not participate. |

A person lives in three family units over a life: the one they are born into, the one they build, and the one they retire into. Sarah, in the simulation, is a child in her mother's unit and is expected to start her own later. The record has to be able to show that. How a person sits in two units at once is not specified.

A person the source lists as outside a family unit is still a family unit in the first version: a unit of one, or a larger unit such as an orphanage ([Q11](open-questions.md)). Labels applied to a person, such as Good, Self-sufficient, and Broken, are not part of the record ([Q16](open-questions.md)).

### Locality

Work should happen inside one locality. The reasons given are familiarity, the ability to stay in contact for years, ownership by local leaders, and a bond that outlasts a viral donation. A nationwide program grows locality by locality. The boundary is whatever the community workers using the app choose for that place, from a housing block up to a district ([Q6](open-questions.md)).

### What the database is imagined to answer

For a worker: who needs help here, how to reach them, what has already been tried, who is a repeat scam.

For a planner: whether to build a school, a special school, a vocational school, elder facilities, or a port, based on the families who actually live there.

For a family: one place to ask, instead of a different counter for school, food, work, and medicine, and a way through the problem of having no permanent address, bank account, or papers.

For a benefactor: a specific family or a specific need (food, materials, time, a skill), and a way to avoid a fake charity.

For a facilitator: stop duplicating the verification, stop all helping the same family, stop all missing the same family, and move surplus help to a locality that has none. Organizations share one list of family units. When two registrations look like the same unit, the program tells them, so overlapping help can be spread ([Q9](open-questions.md)). When the families who qualify outnumber the help, workers and facilitators choose who receives it. The record can highlight units that have gone without help. It does not choose ([Q12](open-questions.md)). A benefactor or a facilitator is verified by the community workers of that locality before an offer is matched ([Q13](open-questions.md)).

### Government

The source leaves government out of the early argument on purpose. The claim is that people can start Sokong without waiting for a ministry. Government is still one of the four parts of a country, a natural benefactor, a source of external events, and the home of nation planners.

The framework is universal. Malay names are the author's language. The first version is for community workers organizing a locality, and it does not decide a host. The later aim is that the community owns the locality's data, and a government queries it up to a limit and assists as a benefactor. That split is F36, not the first version ([Q2](open-questions.md)).

### The worked story

Mary, a teacher, sees that Sarah, 15, cannot do homework because she works the family food stall at night. The mother is a single parent. Two younger brothers are often alone. Mary enrols them from her phone. Aman, head of the residents' association, and a local representative's office are notified. They visit within the week with a week's food and some cash. The visit finds more: the youngest brother has a learning disability, the middle brother is out of school, rent and utilities are behind.

Workers record the four boxes, all unchecked, and call the unit deteriorating. Short-term help follows the box order. Six months later only basic needs are checked. A year later the middle brother is steered to a vocational boarding school instead of a general school. At a year and a half the first two boxes are checked and the status becomes struggling. At two years Sarah has a scholarship and the dependable-generation box is checked. At seven years both adult children are earning, the family can put a deposit on a low-cost home, and the unit is thriving.

The same chapter includes a failure: Sarah elopes, the brother leaves, the mother and the youngest move in with an uncle. The win the source still claims is the data, a chance to work with the next units those children start, and the discipline to spend scarce help on families who will take part.

Use this story as a narrative check when a PRD is written. It is not, by itself, the requirements.

## Loose ends the source already names

The closing slides list work the author had not done. They are product questions, not features to build in silence:

- How to prevent a family becoming struggling or deteriorating, rather than only helping after.
- Three kinds of people, named Good, Self-sufficient, and Broken, with no definitions in the body.
- A deeper account of the three values, and how a nation teaches them (curriculum, marriage courses, counseling, a campaign).
- Families asking for help.
- Running without government.
- Privacy, named as PDPA and GDPR.
- NGOs that will not share a database.
- People who do not want to help.
- Scam charities, not only scam recipients.
- More families in need than there is help.
- People outside family units: runaways, orphans, people dependent on drugs, people without a home.
- Coordinating help for a mass disaster.
- How a nation adopts the three values at all.
- A diagnosis of Malaysian politics and values. That slide is the author's motive. It does not say the first release is Malaysia.

## Working assumptions

Accepted answers live in [open-questions.md](open-questions.md). The lines below are the ones an agent needs beside the catalog. Do not reopen an answer.

1. The app records help and coordinates it. Counseling, cash, housing, school places, and jobs are delivered by people and organizations. The first version records that delivery when a community worker types it. A systematic feed is later.
2. Status is Deteriorating unless the first two boxes are both checked, Struggling unless all four are checked, and Thriving when all four are checked. Clearing good family unit also clears dependable generation. Clearing basic necessities also clears accumulated wealth, unless the family keeps the wealth and goes without necessities. The family can see the four boxes. A community worker checks them. Contesting a check is F37.
3. Reports about families inside Sokong do not claim the locality-wide percentage. That percentage counts every family in the locality, and F24 is deferred.
4. A community worker types an event from a school or a hospital in the first version.
5. A person outside a typical household is a family unit of one, or a unit such as an orphanage.
6. A national campaign and a school curriculum are outside the app. So is prevention.
7. Benefactors and facilitators are verified by the locality's community workers. Scarce help is ordered by workers and facilitators, not by the software.
8. One list of family units is the record organizations share. Likely duplicates are raised back to them.
9. Web and mobile copy can be localized into any language. The first locale is English.

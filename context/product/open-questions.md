# Open questions

Human answers below were given on 2026-10-28, and the three remainders were closed the same day. Record a later answer here. Do not let an agent pick an answer in order to unblock a spec.

Nothing in this list is still open. Deferred work is named in the catalog: F24, F34, F36, and F37.

## Answers

### Q1

Mara's percentage counts every family unit in the locality, including families Sokong does not track. Sokong tracks families that need support, so its own records cannot produce that percentage. The percentage is not required for the other features. The feature that would need the families outside Sokong is F24, and it waits.

### Q2

The framework is universal. The Malay names are the author's language, not a country the first version is built for.

The first version should be usable without deciding who hosts it. The operator in that version is the community worker organizing a locality.

The later aim, if it is built, is a separate feature (F36): the local community owns the locality's data and is the organizer, because it knows that place. A government can query that data up to a limit still to be defined, and can assist as a benefactor. A national government hosting the whole system is the broader ideal, and it is not the first version.

### Q3

When help is given, the app records it. The record can come from the person or organization doing the helping, or, later, from a systematic event such as a government cash disbursement. The point is to see help already given, avoid repeating it, and spread it toward family units that have not received it. The first version has no agency feed (Q10). Delivery of the help itself stays with people and organizations.

### Q4

Status comes from the four checkboxes, not from the generation-by-wealth table. The table remains the source's definition of the generation and wealth words. The pairs are ordered. A later box does not stay checked, by default, after the earlier box it depends on is cleared.

- If good family unit and basic necessities are not both checked, the status is Deteriorating. This includes every box unchecked, only one of those two checked, and a later box still checked.
- If those two are both checked, and dependable generation and accumulated wealth are not both checked, the status is Struggling. One of the last two checked is still Struggling.
- If all four are checked, the status is Thriving.

Clearing a box pulls the box that depends on it:

- Clearing good family unit also clears dependable generation. A family that is not a good family unit does not have a dependable generation.
- Clearing basic necessities also clears accumulated wealth. The exception is a family that keeps the wealth and goes without necessities rather than sell optional possessions. The status is still Deteriorating, because the first two boxes are not both checked.

Losing one of the first two after all four were checked is the edge this rule is for. It is expected to be rare, because the dependent box clears with it.

### Q5

A community worker marks the boxes, including "good family unit." The evidence for that box is face-to-face contact and the regular visits and chats with the family. The bar is that the family as a whole, on average, is adopting the three values: action, integrity, and selflessness.

The family can always see their own four checkboxes. Contesting a check the worker got wrong is later work (F37). The first version does not include it.

### Q6

A locality has no single legal size. It is the boundary chosen by the community workers who will use the app for that place. It can be as small as a housing block or as large as a district.

### Q7

There is no universal closed list of basic needs. What counts depends on the locality, and it can differ again for a family unit. A rural household with one breadwinner may not need childcare. An urban household may. Roof and food remain the examples the source names. They are not the whole list.

### Q8

Someone enrolling a family on behalf of a member, such as a teacher, may enter the data needed to help that family. That data is stored and is available to the community workers who decide the next step. Each fact has a source. The strongest record is data the responsible community worker has both seen and verified on the visit.

### Q9

There is one list of family units. Organizations register into that list. Duplicates will happen. The program identifies likely duplicates and tells the organizations that those recipients may already be getting help, so the help can be spread. The aim is that organizations share one family-unit record because that is the more efficient way to work. A second book per organization is not the design. Which fields make two records "likely" the same is part of F29, not a second product rule.

### Q10

The first version has no feed from school, hospital, police, court, tax, or social security. A community worker types an external event after contact with the family unit. A systematic feed remains later work (F34), which is one of the two sources Q3 allows.

### Q11

People the source lists as outside a family unit are in the first version. They are still family units: a unit of one person, or a larger unit such as an orphanage. There is no second kind of recipient.

### Q12

When qualified families outnumber the help, community workers and facilitators decide who receives it by looking at the record. The system can highlight family units that have not received help for a while. It does not choose for them. The decision, and who made it, is recorded.

### Q13

Benefactors and facilitators are verified before their offer can be matched. The community workers responsible for that locality do the verification.

### Q14

Prevention, and a campaign or curriculum for the three values, are not this app. The app finds family units that need help, identifies who can help and what they can give, and organizes that help.

### Q15

Both clients can be localized, into any language. The first locale is English. The web client is Nuxt and the mobile client is Flutter ([ADR-0005](../decisions/0005-nuxt-web-and-flutter-mobile.md)). Localization is [ADR-0006](../decisions/0006-clients-are-localizable-english-first.md).

### Q16

Good, Self-sufficient, and Broken, applied to people, are not part of the program. The record is about family units.

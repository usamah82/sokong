# Design

Review pictures for the enrolment wizard, sign-up, email confirmation, and sign-in. Usamah approved [spec.md](spec.md) on 2026-11-03. The account screens follow the spec draft from 2026-11-11. Sample names and the place "Block 4" are there so the layout can be judged. They are not default form values.

Submitter progress, the worker case, and the locality boundary are later pictures. This pass is the phone form, the enrolment confirmation, and the email confirmation flow.

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

Type is the system sans at 16px. The stage title is 22px. Labels are 14px. Inputs are at least 44px tall. Page padding is 16px, and the column is 390px wide.

Patterns this screen rejects: a hero, a card grid, purple, and placeholder copy in place of the spec's sentences.

## Phone width

Every picture is 390 CSS pixels wide. The form scrolls vertically. It does not scroll horizontally. Open `design/preview.html` and add `?screen=` with one of the names below.

## Screens

### Who is enrolling

Job: choose self or on behalf, leave a phone, and optionally an email.

Primary action: Next. It stays on this stage until the phone matches the spec's pattern.

States: self selected on arrival; on behalf, with the other consent sentence; an invalid phone.

Copy, as in the spec:

- "This is my family"
- "I am enrolling this family for them"
- "Submission means the family consents. That consent is confirmed at the verification visit."
- "This case is valid and will be checked at a visit. It may not be enrolled unless the family consents then."

The phone label is "Your phone". The error under a bad value is "Enter a phone number, for example +60 12-345 6789."

Pictures: [stage-1.png](design/stage-1.png), [stage-1-on-behalf.png](design/stage-1-on-behalf.png), [stage-1-error.png](design/stage-1-error.png).

### The family

Job: name the place, confirm the family phone, and record the head.

Primary action: Next. Back returns to stage 1 without clearing typed values.

The picture shows the state after "Use my current location" suggested a place, with working turned on so the job and the monthly amount are visible. Those two fields stay hidden when working is off. Gender starts on Unspecified; the sample head is Female. Age and the rough monthly amount are integer fields. The sample amount is 800.

Copy:

- "This place was suggested from your current location."
- "You can name a different place if you are not with the family."

The family phone shows the enroler's phone because this sample is self-enrolment.

Picture: [stage-2.png](design/stage-2.png).

### Other people in the family

Job: add anyone besides the head, or continue with no one else.

Primary action: Next, available with zero other people. "Add a person" inserts the same fields as the head. Remove drops that person.

Pictures: [stage-3.png](design/stage-3.png), [stage-3-member.png](design/stage-3-member.png).

### Notes for the community worker

Job: say how to find the family and what help they are asking for. Every field may be empty.

Primary action: Submit.

Help choices are Food, Clothing, School supplies, and "Help applying to a body (for example social security, welfare, or a tithe body)". Description, how to find them, and the other-help field are textareas at least three lines tall.

Picture: [stage-4.png](design/stage-4.png).

### Confirmation

Job: tell the submitter the case is in, and that no visit is set, before any account exists.

There is no step indicator and no second submit.

Copy:

- "This case is in. No visit is set."
- "Sign up with this email to see who has looked and whether a visit is set."

Picture: [confirmation.png](design/confirmation.png). The email line is omitted when they left email blank. This picture includes it.

### Sign up

Job: create a submitter account for the email used on the enrolment. The form does not offer a role, and it does not sign the person in.

Primary action: Create account. It stays on this screen until the email, the password, and the confirmation are acceptable.

States: empty; password confirmation does not match; the confirmation message has been queued; too many attempts.

Copy, as in the spec:

- "Password confirmation does not match"
- "Check your email to confirm this address. Then sign in."
- "Too many attempts. Try again later."

The queued state shows the address they typed, in the same muted line as the enrolment confirmation. Submitting the form again is how another confirmation message is requested. That state has no second button.

Pictures: [sign-up.png](design/sign-up.png), [sign-up-error.png](design/sign-up-error.png), [sign-up-sent.png](design/sign-up-sent.png), [sign-up-limited.png](design/sign-up-limited.png).

### Email confirmation

Job: accept the link from the confirmation message, without signing the person in.

Primary action: Sign in, only after the link is accepted. An invalid, used, or expired link offers Sign up, which is how a new message is requested.

States: the link worked; the link is invalid.

Copy, as in the spec:

- "This email is confirmed. Sign in."
- "Confirmation link is invalid"

The token from the link is not shown.

Pictures: [confirm.png](design/confirm.png), [confirm-invalid.png](design/confirm-invalid.png).

### Sign in

Job: issue a token after the email is confirmed. A wrong password does not say whether the email exists.

Primary action: Sign in.

States: empty; the password is right but the email is not confirmed; the email or password is wrong.

Copy, as in the spec:

- "Confirm your email to sign in"
- "Email or password is wrong"

There is no password reset on this screen.

Pictures: [sign-in.png](design/sign-in.png), [sign-in-unconfirmed.png](design/sign-in-unconfirmed.png), [sign-in-wrong.png](design/sign-in-wrong.png).

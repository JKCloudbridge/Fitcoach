# FitCoach — Concept & Requirements Review

As of 2026-09-23.

## What FitCoach Is

FitCoach replaces the paper workout card, the WhatsApp thread, and the spreadsheet a gym trainer currently juggles to run their clients, with one connected app all three sides can see: the client, the trainer, and the gym that employs the trainer.

**For a client:** a phone app showing today's assigned workout, a place to log what they actually did (not just what was planned), and steps/heart rate/sleep pulled in automatically from their watch or phone. Daily habits (water, protein, sleep, no alcohol) are tracked alongside workouts, not as a separate app.

**For a trainer:** build a workout plan once, assign it to any number of clients, see who is actually doing it, and message clients from the same app. A trainer's client list can mix people they already know (private coaching, or a gym's roster) with strangers who discover them inside the app.

**For a gym:** license "seats" so every trainer on staff runs their whole roster through one system, giving gym management visibility across all trainers at once. This is a retention tool for the gym, not just a workout tracker for the trainer.

**The marketplace angle:** any trainer, even one with no gym affiliation, can package a multi-week program and sell it directly to people who find them inside the app, with FitCoach automatically splitting the payment. Think Udemy or Patreon, but for fitness coaching — this is also how a brand-new trainer with no existing client base gets discovered at all.

## Business Value — Why Each Side Would Actually Use This

### Clients
- One place instead of three: no more lost paper cards, buried WhatsApp messages, or a coach's personal spreadsheet.
- Progress is verifiable, not self-reported — wearable data (steps, heart rate, sleep) sits next to logged sets, so "I trained hard" has evidence behind it.
- Habits (sleep, hydration, protein) are tracked next to workouts, addressing the reality that results mostly happen between sessions, not during them.
- Can find a coach without knowing one personally — the Discover/marketplace surface turns coach discovery from word-of-mouth into a real acquisition channel for the client, too.

### Coaches / Trainers (especially independent ones)
- One system for every client relationship regardless of how it started — private 1:1, a gym roster, or a marketplace subscriber — instead of juggling spreadsheets, WhatsApp, and Google Sheets per client.
- A path to income that isn't 1:1-time-capped: a Program built once can be sold to many clients (§11 of the requirements doc), which is the single biggest lever an independent trainer has to grow revenue without working more hours.
- Built-in credibility signals (verified badge, public follow/completion counts) help a trainer with no existing following get discovered — today that trainer has no way to be found by a stranger at all.
- Data-backed coaching: a trainer sees adherence and wearable trends, not just what a client says in a check-in message, so they can intervene before a client quietly drops off.

### Gyms
- Seat licensing turns an internal operations tool (trainers tracking clients) into a member-retention tool — a client logging workouts and habits inside "the gym's app" has more switching friction than one with just a punch card.
- Roster-wide visibility for gym owners/managers: adherence and engagement across every trainer's clients, not just anecdotes at the front desk.
- A genuine differentiator in a market where gyms increasingly compete on service and member experience, not just equipment.

### FitCoach (the platform)
- Two revenue lines that don't cannibalize each other: seat licensing behaves like predictable subscription MRR; marketplace take-rate is growth-linked upside tied to how much content trainers publish.
- Every logged workout, habit, and wearable sync makes a client's history more valuable to keep in one place — this is a real retention/data moat if the core loop (below) proves out, not before.

## What's Strong in the Requirements Doc (v3)

The doc (`Initial requirement/Requirement 1`) is unusually mature for a first-pass spec — it reads like it already survived one architecture review, not a first draft. Specifically:

1. **The template/assignment split is the single best decision in the doc.** A workout card (template) is never logged against directly — assigning it creates a frozen snapshot (`assignment_exercises`). This means a trainer editing a template later can't silently rewrite a client's past history, and a client's progress stays correct regardless of how the workout got into their hands (trainer-assigned or self-started from Discover). Getting this wrong is a classic mistake in fitness apps; this doc got it right on the first pass.
2. **Three coaching modes share one data model** (private / gym / public-library), rather than three separate systems bolted together later. Keeps the codebase from splitting into "the gym version" and "the independent trainer version."
3. **RLS policies are written out explicitly**, not hand-waved as "add security later." The doc even notes that Postgres RLS doesn't auto-inherit through foreign keys, and shows the `EXISTS` pattern needed at every level — that's a real, specific, correct detail, not boilerplate.
4. **Wearable credentials are isolated by design** — `wearable_connections.credential_reference` points at a Vault secret rather than storing a raw OAuth token in a normal table. Right instinct for handling third-party health-data credentials.
5. **Habit tracking deliberately mirrors the workout structure** (template → per-client instance → log). Same shape, same reasoning, half the design work, and a consistent mental model for whoever builds the UI.
6. **The two revenue models were identified early and kept separate in the schema** (`subscriptions`/`invites` for seats vs. `programs`/`program_subscriptions`/`payouts` for the marketplace) — that's real product thinking, not "add payments somewhere."
7. **Deferred decisions are named, not hidden.** §8 and §14 explicitly list what was deliberately left unbuilt and why (full version history, full per-set logging, video CDN choice, org role permission matrix). That kind of honesty in a spec is rare and valuable — it tells a reader what NOT to assume is settled.
8. **The compliance note in §11.8 is a genuine strength, not a footnote.** Flagging that split marketplace payouts trigger RBI Payment Aggregator regulations plus GST/TDS handling, and that this needs a CA/fintech consultant before real money moves, shows the doc's author understood this isn't just an engineering problem.

## What Needs Scrutiny or Change

1. **Scope is five products, not one.** The doc bundles a workout logger, a habit tracker, a wearable-data integrator, a messaging system, and a full marketplace-with-payouts — each of which is a standalone app category on its own (compare Trainerize, Streaks, Whoop, a generic chat SDK, and Gumroad, respectively). Building all of it before confirming trainers and clients actually adopt the *core loop* (assign a workout → log it → see progress) is the classic risk of a requirements doc written in "design everything" mode rather than "what's the smallest thing that proves value" mode. **Recommendation:** treat §9–§11 (habits, wearables, seats, marketplace) as a roadmap to revisit after Milestones 0–2 prove the core loop works with real trainers and clients, not as a fixed v1 scope. This is already how `Plan.md`'s milestone sequencing is structured — flagging here so it's a conscious stakeholder decision, not just an engineering default.

2. **No competitive framing anywhere in the doc.** There is zero mention of Trainerize, TrueCoach, My PT Hub, or Fitbod — all of whom already do some version of "trainer assigns workout, client logs it." The doc is 100% schema and API; it never answers "why would a coach switch to this." That's not an engineering gap, it's a missing product-strategy input this document can't supply on its own — worth a short competitive teardown before locking the marketplace/pricing design in §10–§11.

3. **Seat licensing and the marketplace both monetize the same asset — a coach's relationship with a client — through two different mechanics**, and the doc doesn't yet say how they interact for a trainer using both. A trainer could end up paying a seat fee *and* giving up a platform cut on clients who technically came in through the seat/invite path if the boundary isn't crisp. This needs a plain-language rule ("seats are for clients you already have; the marketplace cut is only on clients we found for you") settled before it's built, or trainer-facing pricing will be confusing.

4. **Stacked take rate risk.** A 15–25% marketplace platform fee (§11.6) on top of a seat fee (§10) is a lot of margin pressure on independent trainers, who in the Indian market often charge modest amounts. Worth modeling actual rupee numbers for a realistic trainer (e.g., 20 clients, ₹1,500/month each) before committing to a fee range, rather than citing "typical marketplace range" as if it's self-justifying.

5. **§6.6/§12's wearable sync description is technically inaccurate for two of the three platforms it names.** "`sync-wearable-data`... pulls from HealthKit/Health Connect/OAuth partners" treats all three as server-pullable. Apple HealthKit and Android Health Connect are **on-device only** — there is no server-side API to pull from them; the phone app has to read the data locally and push it up itself. Only true OAuth partners (Fitbit, Garmin, Whoop) can actually be pulled server-side on a schedule. This needs correcting before Milestone 5 is built, or the job will be designed against an API that doesn't exist.

6. **No mention of health-data privacy/consent anywhere in the doc.** `wearable_metrics` carries heart rate and sleep data — Apple's App Store review specifically scrutinizes HealthKit apps for a disclosed privacy policy and restricts using health data for advertising; India's DPDP Act 2023 also applies to this category of data. This is a real App Store approval blocker for Milestone 5, not a nice-to-have — needs a privacy policy and an explicit consent screen designed in, not assumed.

7. **`organization_members` role permission matrix is named as unresolved by the doc itself (§14)**, but it blocks real functionality: can a gym "admin" remove a trainer, reassign their clients? Without this decided, Milestone 7 (gym seats) can only be built up to "seats exist," not "a gym can actually run its roster." Surfacing again here because it's easy to lose in a long open-decisions list.

8. **No operational story for trainer churn.** If a trainer leaves a gym or stops coaching, what happens to their clients' active `workout_assignments`? The doc's schema can represent this (relationships have a `status`) but the doc never describes the actual flow — does the client keep their history, get reassigned, get notified? Worth a short answer before gym pilots start, since this will happen in practice within weeks of any real gym onboarding.

## Build Sequencing

The build plan (`Plan.md`) already sequences around point 1 above: Milestones 0–2 build only the core loop — trainer assigns a card, client logs it, progress reflects it — before anything else is touched. Milestones 3–8 layer on top without reopening the core tables, so pausing after any milestone still leaves a working, demoable product rather than a half-built feature.

| # | Milestone | What it proves |
| --- | --- | --- |
| 0 | Foundation | Project scaffold, database, auth-role plumbing — no user-facing feature yet. **Done as of this doc.** |
| 1 | Auth & roles | A trainer and a client can each sign in and land in their own view of the app |
| 2 | Core coaching loop | The actual value proposition: trainer builds a workout, assigns it, client logs it, both see it reflected |
| 3 | Discover & self-directed | A client can find and start a public workout without a coach |
| 4 | Progress & habits | Adherence charts, streaks — the motivation layer |
| 5 | Wearables | Steps/heart rate/sleep flow in automatically (needs the HealthKit/Health Connect correction noted above) |
| 6 | Messaging & notifications | Trainer and client can talk inside the app instead of switching to WhatsApp |
| 7 | Gym seat licensing | A gym can run its whole roster through the app (blocked on the role permission matrix decision above) |
| 8 | Marketplace & payouts | Real money changes hands between clients, trainers, and the platform — requires the compliance sign-off noted in the doc's own §11.8 before going live |

**The recommendation from this review:** validate Milestones 0–2 with real trainers and clients before committing engineering time to 5–8. Everything past the core loop is genuinely valuable *if the core loop is adopted* — but building the marketplace and payout infrastructure first, before confirming anyone wants the basic assign-and-log workflow, is the highest-risk ordering available.

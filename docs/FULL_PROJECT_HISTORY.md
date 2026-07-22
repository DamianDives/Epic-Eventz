# EpicEventz — Complete Project History

**Repository:** https://github.com/DamianDives/Epic-Eventz
**Salesforce Org:** epicevents@gmail.com (alias: `EpicEventz`), Trailhead Playground
**Project type:** Salesforce DX (SFDX) project, deployed entirely via CLI (`sf project deploy start`), no manual point-and-click config for any object/field/code
**Purpose of this doc:** A step-by-step, chronological account of every action taken since the project started, so you know exactly what exists, why it exists, and what (if anything) you still need to do manually in Setup / Experience Builder.

---

## Table of Contents

1. [Setup & Org Connection](#1-setup--org-connection)
2. [Phase 1 — Core Schema](#2-phase-1--core-schema)
3. [Phase 2 — Registration, Capacity, Waitlist](#3-phase-2--registration-capacity-waitlist)
4. [Phase 2 Rebuild — Switch from Flow to LWC](#4-phase-2-rebuild--switch-from-flow-to-lwc)
5. [GitHub Repository Setup](#5-github-repository-setup)
6. [Phase 4 — Credit Validation](#6-phase-4--credit-validation)
7. [Live End-to-End Test ("KarthikHacks")](#7-live-end-to-end-test-karthikhacks)
8. [Major UI/UX Overhaul](#8-major-uiux-overhaul)
9. [Self-Registration System (LWR Site)](#9-self-registration-system-lwr-site)
10. [My Registrations + Cancel + Waitlist Promotion](#10-my-registrations--cancel--waitlist-promotion)
11. [Login Redirect Fix (guest → login enforcement)](#11-login-redirect-fix-guest--login-enforcement)
12. [Homepage Redesign (v1 then v2)](#12-homepage-redesign-v1-then-v2)
13. [Critical Bug Fix: MIXED_DML_OPERATION on Signup](#13-critical-bug-fix-mixed_dml_operation-on-signup)
14. [Critical Bug Fix: Login "[object Object]" / Invalid Page](#14-critical-bug-fix-login-object-object--invalid-page)
15. [Current State — What Exists Right Now](#15-current-state--what-exists-right-now)
16. [What YOU Still Need To Do Manually](#16-what-you-still-need-to-do-manually)
17. [Every Git Commit, In Order](#17-every-git-commit-in-order)

---

## 1. Setup & Org Connection

**What happened:**
- You provided a Trailhead Playground org: username `epicevents@gmail.com`, org name "EPIC EVENTZ".
- I confirmed the Salesforce CLI (`sf`, v2.136.8) was already installed on your machine.
- Ran `sf project generate --name EpicEventz` inside `C:\Users\karth\OneDrive\Desktop\finalll` to scaffold a fresh SFDX project. This created:
  - `sfdx-project.json` (project config, API version)
  - `force-app/main/default/` (the actual metadata source tree — everything lives under here)
  - `.forceignore`, `.gitignore`, `.prettierrc`, `eslint.config.js`, `jest.config.js`, `package.json` — standard SFDX scaffolding files
  - `scripts/apex/hello.apex`, `scripts/soql/account.soql` — SFDX default sample scripts
- Authenticated the CLI to your org: `sf org login web --alias EpicEventz --set-default`. This opened a browser OAuth flow; you logged in with `epicevents@gmail.com`. The org is now the CLI's default target, so every `sf project deploy start ... --target-org EpicEventz` command since has gone straight into this org.

**Why:** Everything in this project is deployed as source-controlled metadata via CLI, never hand-clicked in Setup, so that the entire build is reproducible and versioned in Git.

---

## 2. Phase 1 — Core Schema

Built from the original task list (Phase 1: UC-01, UC-02, UC-03).

### 2.1 Objects Created

| Object | API Name | Name Field | Key Fields |
|---|---|---|---|
| Venue | `Venue__c` | Auto Number `VEN-{0000}` | `Capacity__c`, `Country__c`, `State__c`, `City__c`, `Venue_Type__c` (picklist), `Address__c`, `Active__c` |
| Event | `Event__c` | Text | `Event_Type__c`, `Event_Status__c`, `Start_Date__c`, `End_Date__c`, `Budget__c`, `Expected_Revenue__c`, `Approved_Budget__c`, `Max_Capacity__c`, `Approval_Status__c`, `Venue__c` (Lookup, not Master-Detail) |
| Attendee | `Attendee__c` | Text | `Email__c` (Unique + External ID), `Phone__c`, `Company__c`, `Country__c`, `Credit_Limit__c`, `Preferred_Currency__c`, `VIP_Status__c` |
| Registration | `Registration__c` (junction) | Auto Number `REG-{00000}` | Master-Detail to `Event__c` AND Master-Detail to `Attendee__c`, `Reg_Date__c`, `Status__c`, `Reg_Amount__c`, `Converted_Amount__c`, `Waitlist_Position__c`, `Payment_Status__c`, `Credit_Validation_Status__c` |

**Decision made:** `Event__c.Venue__c` is a **Lookup**, not Master-Detail — deliberately, so an Event can be saved without a Venue, and deleting a Venue doesn't cascade-delete Events.

**Decision made:** Since Salesforce only allows ONE Auto Number field per object (the Name field), `Venue_Code__c` and `Reg_Number__c` from the original spec were folded directly into each object's **Name** field instead of being separate fields.

### 2.2 Roll-Ups & Formulas

- `Event__c.Total_Registrations__c` — Roll-Up Summary, COUNT of `Registration__c`
- `Event__c.Confirmed_Registrations__c` — Roll-Up Summary, COUNT where `Status__c = 'Confirmed'`
- `Event__c.Total_Revenue__c` — Roll-Up Summary, SUM of `Reg_Amount__c`
- `Event__c.Seats_Available__c` — Formula: `Max_Capacity__c - Total_Registrations__c`
- `Attendee__c.Registration_Count__c` — Roll-Up Summary, COUNT of `Registration__c`
- `Registration__c.Waitlist_Status__c` — Formula (checkbox): `IF(ISPICKVAL(Status__c,'Waitlisted'), TRUE, FALSE)`

(These roll-ups only work because `Registration__c` has real Master-Detail relationships to both `Event__c` and `Attendee__c`.)

### 2.3 Venue Double-Booking Prevention (Apex)

- **`EventTrigger.trigger`** — fires `before insert, before update` on `Event__c`.
- **`EventTriggerHandler.cls`** — the actual logic:
  - Collects all incoming Events that have a Venue + both dates set.
  - Runs ONE bulk SOQL query for all existing Events at those venues (not one query per record).
  - Compares date ranges in memory using the overlap rule: `start1 < end2 AND end1 > start2`.
  - Also checks for overlaps *within the same insert batch* (so bulk-inserting 200 events at once still catches conflicts between them, not just against what's already saved).
  - Calls `addError()` on any Event that overlaps another Event at the same Venue. Error message: *"This venue is already booked for the selected dates. Please choose different dates or a different venue."*
- **`EventTriggerHandlerTest.cls`** — 5 test methods: single insert success, overlapping insert blocked, non-overlapping insert allowed, update-into-overlap blocked, bulk insert with mixed overlaps. All passing.

### 2.4 Capacity Validation Rule (declarative, not Apex)

- **`Max_Capacity_Exceeds_Venue`** validation rule on `Event__c`.
- Formula: `AND(NOT(ISBLANK(Venue__c)), NOT(ISBLANK(Max_Capacity__c)), Max_Capacity__c > Venue__r.Capacity__c)`
- Blocks saving an Event whose `Max_Capacity__c` exceeds its Venue's `Capacity__c`.

### 2.5 Permission Set

- **`EpicEventz_Admin`** — created to grant full CRUD + field-level security on all 4 custom objects, because a fresh Trailhead Playground's System Administrator profile does **not** automatically get FLS on new custom fields; without this, seed data inserts and later trigger/test runs would fail with "insufficient field permissions."

### 2.6 Seed Data

- **`scripts/apex/seedData.apex`** — anonymous Apex script that creates:
  - 3 Venues (San Francisco 500 cap, NYC 200 cap, London 1000 cap)
  - 5 Events (Tech Summit, AI Workshop, Cloud Seminar, DevOps Meetup, Web Dev Bootcamp)
  - 12 Attendees (mixed countries/currencies)
  - 10 Registrations linking them together
- Run via `sf apex run --file scripts/apex/seedData.apex --target-org EpicEventz`.

**Documented in:** `docs/Phase1_Completion.md`

---

## 3. Phase 2 — Registration, Capacity, Waitlist

Original plan used a **Screen Flow** calling an invocable Apex method — this is the *first* version, later replaced (see Section 4).

### 3.1 `RegistrationService.cls`

- `@InvocableMethod` labeled "Register Attendee" — designed to be callable from a Flow.
- Logic: bulk-finds-or-creates Attendee by email, checks Event capacity, sets `Status__c` to `Confirmed` or `Waitlisted` with a sequential `Waitlist_Position__c`.
- **Still exists in the codebase today**, kept as a reusable invocable entry point for any future bulk/API/Flow use, even though the UI no longer uses a Flow.

### 3.2 `RegistrationTrigger.trigger` + `RegistrationTriggerHandler.cls`

- Trigger fires `before insert, after update` on `Registration__c`.
- **`handleBeforeInsert`**: if a record arrives with `Status__c` = `'Registered'` or null (i.e., NOT already pre-set by a controller), bulk-checks capacity and sets Confirmed/Waitlisted + position — with batch-aware counting so a single bulk insert of e.g. 10 records against 5 remaining seats correctly splits into 5 Confirmed + 5 Waitlisted instead of all 10 reading the same stale capacity number.
- **`handleAfterUpdate`**: detects when a record's `Status__c` flips from `'Confirmed'` to `'Cancelled'`, and enqueues `PromoteWaitlistJob` for that Event.

### 3.3 `PromoteWaitlistJob.cls` (Queueable)

- Runs async (outside the trigger's transaction) to avoid governor-limit/mixed-DML issues.
- Finds the Registration with the lowest `Waitlist_Position__c` for the given Event, sets it to `Confirmed`, clears its position.
- Calls `RegistrationEmailService.sendPromotionEmails()`.
- Declared `public without sharing` and uses `Database.update(toPromote, AccessLevel.SYSTEM_MODE)` — needed because the org enforces field-level security on the `Status__c` picklist and the async context otherwise wouldn't have write access.

### 3.4 `RegistrationEmailService.cls`

- `sendPromotionEmails(List<Registration__c>)` — builds and sends a `Messaging.SingleEmailMessage` to the promoted attendee: subject *"You're In! Registration Confirmed - {Event Name}"*, body with event dates.
- Uses `Messaging.sendEmail(emails, false)` so delivery failures don't throw.

### 3.5 Test Coverage

- **`RegistrationTriggerHandlerTest.cls`** — 5 methods: single insert under capacity, insert-at-capacity waitlists correctly, bulk insert with mixed capacity, cancel-confirmed-promotes-waitlist, sequential waitlist position numbering. All passing.

**Documented in:** `docs/Phase2_Completion.md`

---

## 4. Phase 2 Rebuild — Switch from Flow to LWC

**Why this happened:** You explicitly said *"stop using anything declarative i.e which needs manual intervention. i will go with lwc and lwr website this time around."* The Screen Flow from Section 3 required manual Flow Builder work, which conflicted with the "everything deployable by CLI" requirement.

**What changed:**
- Kept all the Phase 2 Apex (trigger, handler, Queueable, email service) — that logic was sound and object-agnostic.
- **Added `RegistrationController.cls`** — a plain `@AuraEnabled` Apex class for an LWC to call directly, replacing the Flow:
  - `getPublishedEvents()` — `cacheable=true`, returns all `Event__c` where `Event_Status__c = 'Published'`.
  - `registerForEvent(eventId, attendeeName, email, phone, company, regAmount)` — finds-or-creates the Attendee, checks capacity, sets Confirmed/Waitlisted, inserts the Registration, returns a result wrapper.
- **Added `RegistrationControllerTest.cls`** — 4 tests covering get-events, new-attendee-confirmed, existing-attendee-reuse, and waitlisted scenarios.
- **Built `eventRegistration` LWC** (first version) — a 3-step wizard:
  1. Select Event (card grid)
  2. Attendee details form
  3. Confirmation screen (Confirmed/Waitlisted/Error)
- **Added `Event_Registration_Page.flexipage-meta.xml`** — a Lightning App Page hosting the LWC, deployable via CLI (so no manual App Builder drag-and-drop was needed for the *internal* Salesforce-side page).

**Documented in:** `docs/Phase2_Implementation_Guide.md` (architecture diagrams, full data flow walk-through for both the "normal registration" and "waitlist promotion" scenarios).

---

## 5. GitHub Repository Setup

- Initialized git in the project folder: `git init`.
- You created the actual GitHub repo yourself at `https://github.com/DamianDives/Epic-Eventz.git` (I don't have a way to create repos on your GitHub account directly — `gh` CLI wasn't installed).
- Ran `git remote add origin ...`, `git branch -M main`, `git push -u origin main`.
- **First commit** (`71156d5`): *"Phase 1-3: Core schema, Registration+Waitlist LWC, Budget Approval governance"* — 102 files. This single commit bundled together everything built up to that point (Phase 1, Phase 2/2-rebuild, and Phase 3 — see Section 6 below for Phase 3, which was built in parallel before this first push).

From this point on, **every subsequent change was deployed to the org first, then committed and pushed to GitHub** — that pattern holds for the rest of this document; I won't repeat "deployed then pushed" for every single item below unless something unusual happened.

---

## 6. Phase 3 — Governance (Budget Approval)

*(Built before the first GitHub push, bundled into that same first commit.)*

### 6.1 Permission Sets for Financial Data

- **`EpicEventz_Finance`** — a NEW permission set granting Read/Edit on exactly three sensitive fields: `Event__c.Budget__c`, `Event__c.Approved_Budget__c`, `Attendee__c.Credit_Limit__c`.
- **`EpicEventz_Admin`** — updated to also carry those same field permissions (so admins aren't locked out), while `EpicEventz_Finance` remains the *specific* gate for non-admin finance staff.

### 6.2 Budget Approval — first attempt (Salesforce Approval Process API) — abandoned

- Initially tried building this using the native `Approval.process()` / `ProcessInstanceWorkitem` APIs (the formal Salesforce Approval Process engine).
- **This was abandoned** because a real Approval Process has metadata dependencies (email templates, field updates, approval page layouts) that don't reliably deploy standalone via CLI in a fresh playground.

### 6.3 Budget Approval — actual implementation: pure Apex, no Approval Process

- **`BudgetApprovalController.cls`**:
  - `submitForApproval(eventId, comments)` — if `Budget__c <= $10,000`, auto-approves immediately (sets `Approval_Status__c = 'Approved'`, `Event_Status__c = 'Published'`). If over $10,000, sets `Approval_Status__c = 'Pending'` and waits for a human.
  - `approveEvent(eventId, comments)` — sets Approved, copies `Budget__c` into `Approved_Budget__c`, publishes the event. **Restricted**: checks `hasFinancePermission()` first (see Section 6.4) and refuses if the caller isn't Finance/Admin.
  - `rejectEvent(eventId, comments)` — sets Rejected, reverts Event to Draft.
  - `getEventsForApproval()` — cacheable, returns all Pending events.
  - `getAllEventsForSubmission()` — cacheable, returns Draft events not yet submitted.
- **`hasFinancePermission()`** private helper — queries `PermissionSetAssignment` for the current user against `EpicEventz_Finance`, OR checks if their Profile is `System Administrator`. If neither, approve/reject calls fail with: *"Only Finance Managers can approve budgets. Please contact your administrator."*
- **`BudgetApprovalControllerTest.cls`** — 6 tests: auto-approve low budget, high budget goes pending, approve sets Published, reject reverts to Draft, get-pending-list, get-draft-list. All passing.

### 6.4 `budgetApproval` LWC

- Two-tab interface:
  - Tab "Submit for Approval" — datatable of Draft events with a row action to submit.
  - Tab "Pending Approvals" — datatable of Pending events with Approve/Reject row actions.
- Confirmation modal collects optional comments before confirming an action.
- Toast notifications on success/failure via `ShowToastEvent`.
- **Access control lives in Apex, not just the UI** — even if a non-Finance user somehow got this component on their page, the server-side `hasFinancePermission()` check blocks the actual DML.

**Documented in:** `docs/Phase3_Completion.md`

---

## 7. Phase 4 — Credit Validation

**Commit:** `3b7eb40` — *"Phase 4: Credit Validation Service with multi-currency conversion"*

### 7.1 `CreditValidationService.cls`

Standalone service class — not tied to any trigger or controller directly. Can be called from anywhere.

**What it does:**
1. Takes an attendee ID, a registration amount, and the amount's currency.
2. Looks up the attendee's `Credit_Limit__c` and `Preferred_Currency__c`.
3. Converts the registration amount to the attendee's preferred currency using built-in FX rates.
4. Queries all their existing non-cancelled registrations, sums those amounts (also converted).
5. Compares total exposure (existing + new) against the credit limit.
6. Returns a `ValidationResult`: `isValid`, `message`, `totalExposure`, `creditLimit`, `convertedAmount`.

**Built-in FX rates (static map — no external callout):**
- USD=1.00, EUR=1.08, GBP=1.27, INR=0.012, AUD=0.65, CAD=0.74, JPY=0.0067

**Bulk method:** `validateCreditBulk(List<Registration__c>)` — handles 200+ records efficiently with batch-aware exposure tracking (if the same attendee has multiple registrations in the same insert batch, each subsequent one factors in the earlier ones from that batch).

### 7.2 Wired into Registration Trigger

Added `performCreditValidation(newRegs)` as the **first** call inside `RegistrationTriggerHandler.handleBeforeInsert()` — runs BEFORE the capacity/status logic. If credit validation fails, `addError()` blocks the insert entirely (the record never gets to the capacity check).

Also sets `Credit_Validation_Status__c = 'Passed'` and `Converted_Amount__c = <converted value>` on successful validation.

### 7.3 Wired into RegistrationController

`RegistrationController.registerForEvent()` now calls `CreditValidationService.validateCredit()` BEFORE inserting the Registration. If credit is exceeded, it returns `success=false` with the credit limit error message — the LWC shows it on Step 3 as an error.

### 7.4 Test Coverage

**`CreditValidationServiceTest.cls`** — 10 test methods:
1. Under limit passes
2. Over limit fails
3. Existing registrations counted toward exposure
4. Cancelled registrations NOT counted
5. Multi-currency USD→GBP under limit
6. Multi-currency USD→GBP over limit
7. No limit set → validation skipped
8. Currency conversion math (unit test)
9. Trigger blocks over-limit insert (integration test)

All 10 passing. Run verified live: `sf apex run test --class-names CreditValidationServiceTest` — 100% pass.

---

## 8. Live End-to-End Test ("KarthikHacks")

**Script:** `scripts/apex/testAllPhases.apex`

Ran against the live org to verify all 4 phases work together. Created:
- Venue: Bangalore, 50 capacity
- Event: "KarthikHacks", Conference, Oct 15-17, Budget $25k, Max 5

**Results:**
- Phase 1: Double-booking blocked ✅, capacity rule blocked ✅
- Phase 2: 5 registered → all Confirmed ✅, 2 more → Waitlisted (positions 1, 2) ✅, cancel → promotion enqueued ✅
- Phase 3: Budget $25k submitted → Pending ✅, approved → Published ✅, low budget auto-approved ✅
- Phase 4: Under limit passes ✅, over limit blocked ✅, multi-currency conversion correct ✅, trigger blocks over-limit ✅

---

## 9. Major UI/UX Overhaul

**Commit:** `261065d` — *"Major overhaul: aesthetic LWC redesign, page layouts, tabs, app, public registration, role-based approval"*

**Why:** You pointed out the page layouts were empty, the LWC looked basic, there was no LWR-site-ready component, and budget approval had no role restriction. I fixed everything in one batch.

### 9.1 Page Layouts Created

| Layout File | Object | Sections |
|---|---|---|
| `Venue__c-Venue Layout.layout-meta.xml` | Venue__c | Venue Info (type, capacity, active) + Location (country, state, city, address) + System |
| `Event__c-Event Layout.layout-meta.xml` | Event__c | Details (name, type, status, dates, venue) + Capacity & Budget + Metrics + System |
| `Attendee__c-Attendee Layout.layout-meta.xml` | Attendee__c | Personal Info + Financial + Metrics + System |
| `Registration__c-Registration Layout.layout-meta.xml` | Registration__c | Registration Details + Financial + Waitlist & Credit + System |

**Bug fixed during this:** Venue layout originally had `Name` field marked `Required` — invalid for an Auto Number name field. Changed to `Readonly`.

### 9.2 Custom Tabs + Lightning App

- Created 4 tab metadata files: `Venue__c.tab-meta.xml`, `Event__c.tab-meta.xml`, `Attendee__c.tab-meta.xml`, `Registration__c.tab-meta.xml`
- Created `EpicEventz.app-meta.xml` — a Lightning App that bundles all 4 tabs together in the App Launcher.

### 9.3 `RegistrationGuestController.cls`

Same logic as `RegistrationController` but declared `without sharing` — needed for guest/community users on the LWR site who have no record-level access.

### 9.4 `eventRegistrationPublic` LWC (first version)

Same design as the internal `eventRegistration` but wired to `RegistrationGuestController`. Exposed to `lightningCommunity__Page` and `lightningCommunity__Default` targets.

### 9.5 `eventRegistration` LWC Redesigned

Complete CSS/HTML rewrite — modern gradient header, progress stepper, card grid with hover, custom form styling. (Later redesigned again in Section 12.)

### 9.6 Budget Approval Role-Restricted

`hasFinancePermission()` private method added to `BudgetApprovalController`. Only users with `EpicEventz_Finance` permission set or System Administrator profile can approve/reject.

---

## 10. Self-Registration System (LWR Site)

**Commit:** `e85f580` — *"Add self-registration LWC with login/signup for LWR site users"*

### 10.1 `SelfRegistrationController.cls`

- `registerUser(firstName, lastName, email, password)`:
  1. Validates inputs (all required, password ≥ 8 chars)
  2. Checks if User with that username already exists
  3. Finds or creates a Contact under "EpicEventz Community" Account
  4. Creates an `Attendee__c` record (so registrations are linked)
  5. Calls `Site.createExternalUser()` to create the community User
  6. Returns success/failure

- ~~`loginUser(username, password, startUrl)`~~ — **REMOVED in later fix** (see Section 14). Login is now a native HTML form POST.

### 10.2 `selfRegistration` LWC

- Login mode: real `<form method="post">` that submits directly to the site's native `/login` endpoint with fields named `un`, `pw`, `startURL`.
- Signup mode: calls `SelfRegistrationController.registerUser()` via `@AuraEnabled`.
- Toggle between modes via "Don't have an account? Sign Up" / "Already have an account? Log In" links.

---

## 11. My Registrations + Cancel + Waitlist Promotion

**Commit:** `1d9e7ff` — *"Add My Registrations LWC with cancel + waitlist promotion, fix public component redirect to login"*

### 11.1 `MyRegistrationsController.cls`

- `getCurrentUserEmail()` — returns the logged-in user's email.
- `getMyRegistrations(email)` — returns all non-cancelled registrations for that attendee email, with event details.
- `cancelRegistration(regId)` — sets `Status__c = 'Cancelled'`. This fires the existing `RegistrationTrigger (after update)` → `handleAfterUpdate` detects Confirmed→Cancelled → enqueues `PromoteWaitlistJob` → promotes top waitlisted → sends email.

### 11.2 `myRegistrations` LWC

- Shows each registration as a card: event name/type, venue, dates, status badge (Confirmed green / Waitlisted amber), waitlist position, amount.
- "Cancel Registration" button → confirmation modal ("Are you sure?") → on confirm calls `cancelRegistration` → toast notification → list auto-refreshes via `refreshApex`.

---

## 12. Login Redirect Fix (guest → login enforcement)

**Commit:** `c86a261` — *"Fix: eventRegistration now redirects guest users to login before allowing registration"*

**The bug:** When a guest user selected an event and clicked "Continue", it went straight to the details form (Step 2) without checking auth.

**The fix:** Added `import isGuest from '@salesforce/user/isGuest'` to both `eventRegistration` and `eventRegistrationPublic` JS. In `goToStep2()` (and `handleRegisterClick` for the public version): if `isGuest === true`, redirect to `/s/login?startURL=...` with the event ID as a query param.

---

## 13. Homepage Redesign (v1 then v2)

### v1 (commit `b3d287c`) — you called it a copy of the reference

- Built a homepage with purple/gold palette, floating orbs animation, event carousel, testimonials — too similar to the reference site you shared.

### v2 (commit `d8de695`) — genuinely different design

- **Palette:** warm coral (#ff6b5b) + deep teal (#0f3538) on cream (#faf6f0). Totally different feel.
- **Layout:** editorial/magazine style with serif typography (Georgia headings). Split-screen hero (text left, stacked overlapping cards right). NOT a centered hero.
- **Events:** filterable masonry grid with type-chip filters (All / Conference / Workshop / etc.). NOT a carousel.
- **Process section:** horizontal timeline with connected dots. NOT a numbered vertical list.
- **No testimonials section.** Replaced with a stats strip (Live Events count, Instant Confirmation, Auto Waitlisting) and a brief closing CTA.
- **Sticky nav** with a "Member Login" pill button that redirects to `/s/login`.
- **Every event tile** on click redirects to login (same `isGuest` → `/s/login?startURL=...&eventId=...` pattern).

Component name: `epicHomePage`

---

## 14. Critical Bug Fix: MIXED_DML_OPERATION on Signup

**Commit:** `6e1a6f1` — *"Fix MIXED_DML_OPERATION in self-registration; surface real login errors"*

**The bug:** `SelfRegistrationController.registerUser()` was inserting `Attendee__c` (a non-setup object) in the same transaction as `Contact + Site.createExternalUser()` (setup objects). Salesforce blocks this with `MIXED_DML_OPERATION`. The Contact got committed (it ran first), but the User creation threw. Result: orphaned Contact, no User. On retry: "already exists" (finds Contact), still can't create User.

**The fix:**
1. Insert `Attendee__c` FIRST (before any Contact/User DML).
2. Then handle Contact + User together (those two are exempt from mixed-DML rules when done via `Site.createExternalUser`).
3. If a Contact already exists for that email (from a prior crashed attempt), reuse it instead of failing or duplicating.

---

## 15. Critical Bug Fix: Login "[object Object]" / Invalid Page

**Commit:** `95e3551` — *"Fix login redirect bug: use native form POST to site login servlet instead of Apex Site.login()"*

**The bug:** `Site.login()` called from an `@AuraEnabled` method cannot set the session cookie — the LWC/UI-API remoting layer is an XHR call, not a real page load. `pageRef.getUrl()` came back as an object, not a string. `window.location.href = result.redirectUrl` literally navigated to `/epicevents/[object Object]`.

**The fix:** Replaced the entire login mechanism. Login is now a real HTML `<form method="post" action="{loginActionUrl}">` with input fields named `un` and `pw` (same field names the native Salesforce login handler expects). The form action URL points to the site's built-in login servlet. Browser submits it as a genuine page-level POST, Salesforce sets the cookie, redirects properly. No Apex involved in login at all anymore.

---

## 16. Root Cause: Site Not Published

**Discovered after all code fixes:** The Experience Cloud site status was `UnderConstruction`, not `Live`. `Site.createExternalUser()` hard-refuses to run unless the site is actually active. This was the fundamental reason signup never worked — every attempt hit *"That operation is only allowed from within an active site"* regardless of the DML ordering or code quality.

**Fix:** You published the site via Experience Builder. Status changed to Live. Signup should now complete end-to-end.

---

---

## 6. Phase 4 — Credit Validation

**Git commit:** `3b7eb40` — *"Phase 4: Credit Validation Service with multi-currency conversion"*

### 6.1 `CreditValidationService.cls`

A standalone service class (not a controller, not a trigger handler — it gets called by both). Contains:

- **Static currency conversion rates** — a `Map<String, Decimal>` with rates to USD: `USD=1.00, EUR=1.08, GBP=1.27, INR=0.012, AUD=0.65, CAD=0.74, JPY=0.0067`.
- **`convertCurrency(amount, fromCurrency, toCurrency)`** — converts via USD as the intermediate base. Example: GBP→EUR = (amount × GBPtoUSD) / EURtoUSD.
- **`validateCredit(attendeeId, regAmount, regCurrency)`** — single-record validation:
  1. Queries the Attendee's `Credit_Limit__c` and `Preferred_Currency__c`.
  2. If no credit limit set → skips validation (returns valid).
  3. Converts the new `regAmount` from `regCurrency` to the attendee's preferred currency.
  4. Queries ALL existing non-cancelled Registration amounts for this attendee, converts each to the same currency, sums them.
  5. If (existing sum + new amount) > credit limit → returns invalid with a message like *"Credit limit exceeded. Total exposure: 6000.00 USD exceeds limit of 5000.00 USD."*
- **`validateCreditBulk(List<Registration__c>)`** — bulk version of the above, for the trigger context. Does the same logic but with bulk SOQL (one query for all attendees, one for all their existing registrations) and tracks batch-level exposure accumulation (so inserting 5 registrations for the same attendee in one batch correctly accumulates).

### 6.2 Wired Into the Registration Trigger

- `RegistrationTriggerHandler.handleBeforeInsert()` now calls `performCreditValidation(newRegs)` BEFORE the capacity/waitlist logic.
- If credit validation fails for a record → `reg.addError(vr.message)` — blocks the insert entirely for that record.
- If it passes → sets `Credit_Validation_Status__c = 'Passed'` and `Converted_Amount__c` = the converted amount.

### 6.3 Also Wired Into RegistrationController

- `RegistrationController.registerForEvent()` calls `CreditValidationService.validateCredit()` before inserting — returns the error to the LWC immediately instead of letting the trigger block it (better UX — the user sees a friendly message, not a raw DML exception).

### 6.4 Test Class

- **`CreditValidationServiceTest.cls`** — 10 methods:
  1. Under limit passes
  2. Over limit fails
  3. Existing registrations counted in total
  4. Cancelled registrations NOT counted
  5. Multi-currency USD→GBP under limit
  6. Multi-currency USD→GBP over limit
  7. No limit set → skips
  8. `convertCurrency()` function directly (USD↔GBP, USD→EUR, USD→INR)
  9. Trigger blocks over-limit insert with `Database.insert(reg, false)`
  - All 10 passing, verified with `sf apex run test`.

---

## 7. Live End-to-End Test ("KarthikHacks")

After Phase 4 was deployed, ran a comprehensive anonymous Apex script (`scripts/apex/testAllPhases.apex`) against the live org to verify everything works together. Created:

- A new Venue in Bangalore (capacity 50)
- An Event "KarthikHacks" (Conference, Oct 15–17, $25k budget, 5 max capacity)
- 7 Attendees

**Phase 1 tests (passed live):**
- Double-booking blocked ✅
- Over-capacity validation rule blocked ✅

**Phase 2 tests (passed live):**
- 5 registrations → all Confirmed ✅
- 2 more → both Waitlisted (positions 1, 2) ✅
- Cancelled Karthik Kaiser → PromoteWaitlistJob enqueued ✅

**Phase 3 tests (passed live):**
- Submit $25k event → Pending ✅
- Approve → Published, Approved_Budget = $25k ✅
- Low budget ($5k) auto-approved ✅

**Phase 4 tests (passed live):**
- $800 on $1000 limit → passed ✅
- $1500 on $1000 limit → blocked ✅
- $4000 USD for GBP attendee (limit 4000 GBP) → converted to 3149.61 GBP, passed ✅
- Trigger blocks over-limit ✅
- Currency conversions verified ✅

---

## 8. Major UI/UX Overhaul

**Git commit:** `261065d` — *"Major overhaul: aesthetic LWC redesign, page layouts, tabs, app, public registration, role-based approval"*

You reported multiple problems: empty page layouts, ugly LWC, no role restriction on approval, no public-facing site component. This commit addressed all of them.

### 8.1 Page Layouts Created

Previously: no layout metadata existed → objects showed blank layouts in the org. Added:

- `Venue__c-Venue Layout.layout-meta.xml` — sections: Venue Information + Location + System Info
- `Event__c-Event Layout.layout-meta.xml` — sections: Event Details + Capacity & Budget + Metrics + System Info
- `Attendee__c-Attendee Layout.layout-meta.xml` — sections: Personal Info + Financial + Metrics + System Info
- `Registration__c-Registration Layout.layout-meta.xml` — sections: Registration Details + Financial + Waitlist & Credit + System Info

**Fix applied:** Venue__c Name field was marked `Required` which is invalid for Auto Number fields. Changed to `Readonly`.

### 8.2 Custom Tabs + Lightning App

Created 4 tab metadata files (`tabs/Venue__c.tab-meta.xml`, etc.) and one Lightning App metadata (`applications/EpicEventz.app-meta.xml`) containing all 4 tabs — so internal users can find objects via App Launcher → EpicEventz.

### 8.3 `eventRegistration` LWC Redesigned

Completely rewrote the HTML/CSS/JS. New design:
- Purple gradient hero header with "EpicEventz" branding
- 3-step progress indicator (Choose Event → Your Details → Confirmation)
- Card-based responsive event grid with hover animations, selection highlighting
- Custom form inputs (not `lightning-input`) with clean labels, 2-column layout
- Success/error states with colored badges and clear messaging

### 8.4 `eventRegistrationPublic` LWC Created

A separate component for the LWR Experience Cloud site (guest-accessible):
- Uses `RegistrationGuestController.cls` (`without sharing` — guests have no record access)
- Shows published events in a card grid
- "Register Now" button checks `isGuest` → if guest, redirects to `/s/login?startURL=...`

### 8.5 `RegistrationGuestController.cls` Created

Same logic as `RegistrationController` but declared `without sharing` so it can run in the guest user context on the LWR site where the user has no org-level object permissions.

### 8.6 Budget Approval Role Check Added

`BudgetApprovalController` already had `hasFinancePermission()` from Phase 3 — this was verified as working correctly during the overhaul (it was already in place before this commit, just confirmed).

---

## 9. Self-Registration System (LWR Site)

**Git commit:** `e85f580` — *"Add self-registration LWC with login/signup for LWR site users"*

### 9.1 `SelfRegistrationController.cls`

- `registerUser(firstName, lastName, email, password)`:
  1. Validates inputs (all required, password ≥ 8 chars)
  2. Checks if a User with that username already exists
  3. Finds-or-creates an "EpicEventz Community" Account
  4. Creates an `Attendee__c` record (so registration data links up later)
  5. Creates a Contact under that Account
  6. Calls `Site.createExternalUser(user, accountId, password)` → creates a Community User
  7. Returns success/failure with message

### 9.2 `selfRegistration` LWC

- Toggle between Login and Sign Up modes
- Sign Up form: First Name, Last Name, Email, Password, Confirm Password → calls `registerUser`
- Login form: Email, Password → submits login
- Error/success messages displayed inline

---

## 10. My Registrations + Cancel + Waitlist Promotion

**Git commit:** `1d9e7ff` — *"Add My Registrations LWC with cancel + waitlist promotion, fix public component redirect to login"*

### 10.1 `MyRegistrationsController.cls`

- `getCurrentUserEmail()` — returns the logged-in user's email
- `getMyRegistrations(email)` — queries all non-cancelled Registration__c records for that attendee email, returns wrapper objects with event details
- `cancelRegistration(regId)` — sets `Status__c = 'Cancelled'` → triggers `RegistrationTrigger` after update → enqueues `PromoteWaitlistJob` → promotes next waitlisted person → sends them an email

### 10.2 `myRegistrations` LWC

- Shows logged-in user's registrations as cards (event name, venue, date, status badge, waitlist position, amount)
- "Cancel Registration" button with confirmation modal
- On cancel → Apex call → list auto-refreshes via `refreshApex`
- Toast notifications for success/error

---

## 11. Login Redirect Fix (guest → login enforcement)

**Git commit:** `c86a261` — *"Fix: eventRegistration now redirects guest users to login before allowing registration"*

**Problem:** The `eventRegistration` LWC (the 3-step wizard) let anyone fill the form — it didn't check if they were logged in before showing Step 2.

**Fix:** Added `import isGuest from '@salesforce/user/isGuest'` and a check in `goToStep2()`:
```javascript
if (this.isGuestUser) {
    window.location.href = loginUrl + '?startURL=...' + eventId;
    return;
}
```
Now guests get redirected to `/s/login` when they try to proceed past event selection.

---

## 12. Homepage Redesign (v1 then v2)

### v1 — Git commit `b3d287c`

Built a homepage with hero, carousel, features, testimonials — you correctly called this out as being too close to a copy of the reference site you showed me.

### v2 — Git commit `d8de695` — *"Redesign homepage: editorial split-hero layout, coral/teal palette..."*

Completely different design:
- **Palette:** warm coral (#ff6b5b) + deep teal (#0f3538) + cream background
- **Typography:** Georgia serif headlines mixed with system-ui sans-serif for UI elements
- **Hero:** Split-screen (text left, stacked overlapping card preview right) — not centered
- **Events:** Filterable masonry grid with type chips (All / Conference / Workshop / etc.) — not a carousel
- **Process:** Horizontal timeline with connecting line and node dots — not numbered vertical list
- **Stats strip:** coral-on-teal band showing live event count
- **Closing CTA:** minimal, no testimonials
- **Nav:** Sticky with "EE." logo, smooth-scroll links, pill-shaped "Member Login" button

All event tiles redirect to login page on click (same `isGuest` → redirect logic as everything else).

---

## 13. Critical Bug Fix: MIXED_DML_OPERATION on Signup

**Git commit:** `6e1a6f1` — *"Fix MIXED_DML_OPERATION in self-registration; surface real login errors"*

**Root cause:** `SelfRegistrationController.registerUser()` was inserting `Attendee__c` (a non-setup custom object) and then calling `Site.createExternalUser()` (a setup-object operation) in the same transaction. Salesforce throws `MIXED_DML_OPERATION` when you mix setup and non-setup DML.

**Symptom:** Contact got created (before the error), Attendee got created (before the error), but the User creation failed. On retry, the code found the existing Contact/Attendee and said "already registered" — but there was no User to log into.

**Fix:**
1. Reordered: `Attendee__c` insert happens first (its own DML), THEN Contact + User (allowed together as setup objects for self-registration).
2. Added Contact reuse: if a Contact with that email already exists from a previous failed attempt, reuse it instead of failing with a duplicate error.
3. Updated login method to return the real Salesforce error message instead of a generic "invalid credentials."

---

## 14. Critical Bug Fix: Login "[object Object]" / Invalid Page

**Git commit:** `95e3551` — *"Fix login redirect bug: use native form POST to site login servlet instead of Apex Site.login()"*

**Root cause:** `Site.login()` was being called from an `@AuraEnabled` method. That method is invoked via the LWC/UI-API remoting layer (an XHR/fetch call). Salesforce cannot properly set the session cookie through XHR — the `PageReference` returned by `Site.login()` came back as an object that, when assigned to `window.location.href`, rendered as the literal string `"[object Object]"`.

**Fix:** Replaced the entire login mechanism. Instead of calling Apex:
- The login form is now a real HTML `<form method="post" action="/epicevents/login">` with input fields named `un` (username), `pw` (password), `startURL` (redirect target).
- This is the exact same mechanism Salesforce's own standard login page uses — a genuine browser form submission that correctly establishes the session cookie and redirects.
- Removed the `loginUser()` Apex method and `LoginResult` class entirely — they're no longer needed.

---

## 15. Critical Issue: Site Not Published

**Discovered during debugging** — your Experience Cloud site had `Status = UnderConstruction`. `Site.createExternalUser()` has a hard platform rule: it only works when called from within an **active (published) site**. Every signup attempt was failing with *"That operation is only allowed from within an active site."*

**Fix (manual — you did this):** Setup → Digital Experiences → All Sites → Publish.

---

## 15. Current State — What Exists Right Now

### Apex Classes (12 production + 5 test)

| Class | Type | Purpose |
|---|---|---|
| `EventTriggerHandler` | Handler | Venue double-booking prevention |
| `RegistrationTriggerHandler` | Handler | Credit validation + capacity/waitlist + cancel detection |
| `RegistrationController` | LWC Controller | Internal registration wizard (authenticated users) |
| `RegistrationGuestController` | LWC Controller | Same but `without sharing` for site guests |
| `SelfRegistrationController` | LWC Controller | Account creation (signup). Login is now native form POST |
| `MyRegistrationsController` | LWC Controller | View/cancel own registrations |
| `BudgetApprovalController` | LWC Controller | Submit/Approve/Reject events (Finance-restricted) |
| `RegistrationService` | Invocable | Bulk registration (for APIs/Flows/Data Loader) |
| `CreditValidationService` | Service | Multi-currency credit limit validation |
| `PromoteWaitlistJob` | Queueable | Async waitlist promotion when spot opens |
| `RegistrationEmailService` | Service | Sends promotion notification emails |

| Test Class | Methods | Covers |
|---|---|---|
| `EventTriggerHandlerTest` | 5 | Double-booking |
| `RegistrationTriggerHandlerTest` | 5 | Capacity/waitlist/promotion |
| `RegistrationControllerTest` | 4 | Controller methods |
| `BudgetApprovalControllerTest` | 6 | Approval workflow |
| `CreditValidationServiceTest` | 10 | Credit + currency |

### LWC Components (6)

| Component | Where It's Used | What It Does |
|---|---|---|
| `epicHomePage` | LWR site Home page | Landing page with hero, filterable event grid, timeline, login redirect |
| `eventRegistration` | Internal Lightning + LWR authenticated pages | 3-step registration wizard |
| `eventRegistrationPublic` | LWR site (public pages) | Event listing cards, redirects to login on click |
| `selfRegistration` | LWR site Login page | Sign Up form (Apex) + Login form (native POST) |
| `myRegistrations` | LWR site (authenticated) | View registrations + cancel |
| `budgetApproval` | Internal Lightning pages | Finance approval queue |

### Triggers (2)

| Trigger | Object | Events |
|---|---|---|
| `EventTrigger` | Event__c | before insert, before update |
| `RegistrationTrigger` | Registration__c | before insert, after update |

### Metadata (non-code)

- 4 object definitions with all fields
- 4 page layouts
- 4 custom tabs
- 1 Lightning App (EpicEventz)
- 1 Flexipage (Event_Registration_Page)
- 2 permission sets (Admin, Finance)
- 1 validation rule (Max_Capacity_Exceeds_Venue)

---

## 16. What YOU Still Need To Do Manually

These are things that cannot be deployed via metadata/CLI and require clicking in Setup or Experience Builder:

| # | What | Where | Why It Can't Be CLI-Deployed |
|---|---|---|---|
| 1 | **Publish the LWR site** | Setup → Digital Experiences → All Sites → Publish | Site publishing is a runtime action, not metadata |
| 2 | **Place LWCs on site pages** | Experience Builder → drag components onto pages | Page composition in Experience Builder isn't source-trackable metadata |
| 3 | **Grant Guest User Apex access** | Guest Profile → Enabled Apex Class Access → add `RegistrationGuestController`, `SelfRegistrationController` | Profile settings for guest users aren't easily deployable in playgrounds |
| 4 | **Grant Guest User object permissions** | Guest Profile → Object Permissions → Read on Event__c, Venue__c; Create on Attendee__c, Registration__c | Same reason |
| 5 | **Assign EpicEventz_Admin to your user** | Setup → Permission Sets → EpicEventz_Admin → Manage Assignments | Assignment is user-specific, not metadata |
| 6 | **Assign EpicEventz_Finance to finance users** | Same flow | Same reason |
| 7 | **Republish site after every deploy** | Experience Builder → Publish | LWR sites cache component bundles; new deploys only take effect after republish |

### LWR Site Page Layout (what goes where)

| Site Page | Component to Place |
|---|---|
| Home | `epicHomePage` |
| Login | `selfRegistration` |
| Register (new page, authenticated) | `eventRegistration` |
| My Registrations (new page, authenticated) | `myRegistrations` |

---

## 17. Every Git Commit, In Order

| # | Hash | Message | What Changed |
|---|---|---|---|
| 1 | `71156d5` | Phase 1-3: Core schema, Registration+Waitlist LWC, Budget Approval governance | 102 files — all objects, fields, triggers, handlers, LWCs, permission sets |
| 2 | `3b7eb40` | Phase 4: Credit Validation Service with multi-currency conversion | CreditValidationService + test, RegistrationTriggerHandler updated |
| 3 | `261065d` | Major overhaul: aesthetic LWC redesign, page layouts, tabs, app, public registration, role-based approval | 23 files — layouts, tabs, app, redesigned LWCs, guest controller |
| 4 | `208b567` | Add complete project reference documentation | docs/COMPLETE_REFERENCE.md |
| 5 | `e85f580` | Add self-registration LWC with login/signup for LWR site users | SelfRegistrationController + selfRegistration LWC |
| 6 | `1d9e7ff` | Add My Registrations LWC with cancel + waitlist promotion | MyRegistrationsController + myRegistrations LWC, rebuilt eventRegistrationPublic |
| 7 | `db83a8e` | Add complete LWR Site Implementation documentation | docs/LWR_Site_Implementation.md |
| 8 | `c86a261` | Fix: eventRegistration now redirects guest users to login | Added isGuest check to goToStep2() |
| 9 | `b3d287c` | Add epicHomePage LWC (v1 — too similar to reference) | First homepage attempt |
| 10 | `d8de695` | Redesign homepage: editorial split-hero layout, coral/teal palette | Complete rewrite — original design |
| 11 | `6e1a6f1` | Fix MIXED_DML_OPERATION in self-registration | Reordered DML, added contact reuse |
| 12 | `95e3551` | Fix login redirect: native form POST instead of Apex Site.login() | Replaced login with HTML form submit |

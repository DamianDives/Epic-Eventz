# EpicEventz — LWR Site Implementation Guide

**GitHub:** https://github.com/DamianDives/Epic-Eventz  
**Last Updated:** July 22, 2026  

---

## Overview

The EpicEventz LWR site allows external users to:
1. Browse published events (without logging in)
2. Create an account / log in
3. Register for events (capacity + credit validation applied)
4. View their registrations
5. Cancel registrations (triggers automatic waitlist promotion + email)

---

## Site Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    LWR SITE (PUBLIC)                           │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  HOME PAGE                                              │  │
│  │  Component: eventRegistrationPublic                     │  │
│  │  • Shows all Published events as cards                  │  │
│  │  • "Register Now" button on each card                   │  │
│  │  • Guest? → Redirects to Login page                     │  │
│  │  • Logged in? → Navigates to Register page              │  │
│  └────────────────────────────────────────────────────────┘  │
│                          ↓                                    │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  LOGIN PAGE                                             │  │
│  │  Component: selfRegistration                            │  │
│  │  • Login form (email + password)                        │  │
│  │  • "Don't have account? Sign Up" link                   │  │
│  │  • Sign Up form (first, last, email, password)          │  │
│  │  • Creates: Contact + Attendee + Community User         │  │
│  │  • After login → redirects back to startURL             │  │
│  └────────────────────────────────────────────────────────┘  │
│                          ↓                                    │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  REGISTER PAGE (authenticated only)                     │  │
│  │  Component: eventRegistration                           │  │
│  │  • 3-step wizard: Select Event → Details → Confirm      │  │
│  │  • Credit validation before insert                      │  │
│  │  • Auto Confirmed or Waitlisted based on capacity       │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  MY REGISTRATIONS PAGE (authenticated only)             │  │
│  │  Component: myRegistrations                             │  │
│  │  • Shows user's active registrations                    │  │
│  │  • Cancel button with confirmation modal                │  │
│  │  • Cancellation triggers waitlist promotion + email     │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

---

## Components & Controllers

### LWC Components

| Component | Purpose | Visibility | Controller |
|-----------|---------|-----------|------------|
| `eventRegistrationPublic` | Event listing with Register buttons | Public (guests can view) | `RegistrationGuestController` |
| `selfRegistration` | Login + Sign Up forms | Public (on login page) | `SelfRegistrationController` |
| `eventRegistration` | Full registration wizard (3 steps) | Authenticated only | `RegistrationController` |
| `myRegistrations` | User's registrations + cancel | Authenticated only | `MyRegistrationsController` |
| `budgetApproval` | Internal budget approval queue | Internal (admin/finance) | `BudgetApprovalController` |

### Apex Controllers

| Class | Sharing | Purpose |
|-------|---------|---------|
| `RegistrationGuestController` | `without sharing` | Serves events to guest users who have no record access |
| `SelfRegistrationController` | `without sharing` | Creates Contact + Attendee + Community User via `Site.createExternalUser()` |
| `RegistrationController` | `with sharing` | Handles registration for logged-in users (internal + community) |
| `MyRegistrationsController` | `without sharing` | Gets user's registrations by email, handles cancellation |
| `BudgetApprovalController` | `with sharing` | Submit/Approve/Reject budgets. Finance permission required to approve |

---

## User Flow: Guest → Account → Register → Cancel

### Step 1: Guest Browses Events

- Component: `eventRegistrationPublic`
- Calls: `RegistrationGuestController.getPublishedEvents()`
- Shows event cards (name, type, venue, date, capacity)
- No login required to view

### Step 2: Guest Clicks "Register Now"

- JS checks `isGuest` (from `@salesforce/user/isGuest`)
- If **guest** → redirects to: `/s/login?startURL=/s/?eventId=<EVENT_ID>`
- If **logged in** → navigates to Register page with event pre-selected

### Step 3: User Creates Account

- Component: `selfRegistration`
- User fills: First Name, Last Name, Email, Password, Confirm Password
- Apex (`SelfRegistrationController.registerUser()`) does:
  1. Validates inputs (all required, password ≥ 8 chars)
  2. Checks if username already exists
  3. Creates a **Contact** under "EpicEventz Community" Account
  4. Creates an **Attendee__c** record (linked by email)
  5. Calls `Site.createExternalUser()` → creates Community User
  6. User gets the site's community profile automatically
- Success → "Account created! You can now log in."

### Step 4: User Logs In

- Same `selfRegistration` component (login mode)
- Calls `Site.login(username, password, startUrl)`
- On success → `window.location.href = redirectUrl` → takes them back to where they came from (with eventId in URL)

### Step 5: User Registers for Event

- Component: `eventRegistration` (full 3-step wizard)
- **Step 1:** Select event (cards with gradient design, hover effects)
- **Step 2:** Fill details (name, email, phone, company, amount)
- **Step 3:** Confirmation screen

Behind the scenes:
1. `RegistrationController.registerForEvent()` called
2. Finds or creates Attendee by email
3. **Credit validation** (`CreditValidationService`) — checks total exposure vs limit
4. **Capacity check** — confirmed count vs Max_Capacity
5. If under capacity → Status = `Confirmed`
6. If full → Status = `Waitlisted`, position assigned
7. Returns reg number + status to UI

### Step 6: User Views Registrations

- Component: `myRegistrations`
- Calls `MyRegistrationsController.getCurrentUserEmail()` → gets logged-in email
- Calls `MyRegistrationsController.getMyRegistrations(email)` → returns all non-cancelled regs
- Shows each registration as a card: event name, venue, dates, status badge, position (if waitlisted), amount, reg number

### Step 7: User Cancels a Registration

- User clicks "Cancel Registration" button
- **Confirmation modal** appears: "Are you sure? This cannot be undone."
- User confirms → `MyRegistrationsController.cancelRegistration(regId)` called
- Sets Status = `Cancelled`
- This update triggers `RegistrationTrigger` (after update):
  - Detects: old Status = Confirmed, new Status = Cancelled
  - Enqueues `PromoteWaitlistJob` for that event

### Step 8: Waitlist Auto-Promotion

- `PromoteWaitlistJob` (Queueable) executes asynchronously:
  1. Queries Registration with lowest `Waitlist_Position__c` where Status = Waitlisted
  2. Sets that registration: Status = `Confirmed`, Position = null
  3. Calls `RegistrationEmailService.sendPromotionEmails()`
- The promoted attendee receives an email:
  - Subject: "You're In! Registration Confirmed - {Event Name}"
  - Body: congratulatory message with event dates

---

## Email Notifications

| Trigger | Who Gets Email | Subject |
|---------|---------------|---------|
| Waitlisted person promoted to Confirmed | The promoted attendee | "You're In! Registration Confirmed - {Event Name}" |

---

## Security & Access

### Who Can Do What

| Action | Guest | Community User | Admin | Finance |
|--------|-------|---------------|-------|---------|
| View events | ✅ | ✅ | ✅ | ✅ |
| Create account | ✅ | - | - | - |
| Register for event | ❌ (redirected to login) | ✅ | ✅ | ✅ |
| View my registrations | ❌ | ✅ | ✅ | ✅ |
| Cancel registration | ❌ | ✅ (own only) | ✅ | ✅ |
| Submit event for approval | ❌ | ❌ | ✅ | ✅ |
| Approve/Reject budget | ❌ | ❌ | ✅ | ✅ |
| View Budget/Credit fields | ❌ | ❌ | ❌ | ✅ |

### Permission Sets

| Permission Set | Grants |
|---------------|--------|
| `EpicEventz_Admin` | Full CRUD all objects + all fields (except financial) |
| `EpicEventz_Finance` | Budget, Approved_Budget, Credit_Limit fields + approve/reject ability |

---

## LWR Site Pages to Configure

In **Experience Builder**, create these pages and drag the components:

| Page Name | URL | Component | Access |
|-----------|-----|-----------|--------|
| Home | `/s/` | `eventRegistrationPublic` | Public |
| Login | `/s/login` | `selfRegistration` | Public |
| Register | `/s/register` | `eventRegistration` | Requires Authentication |
| My Registrations | `/s/my-registrations` | `myRegistrations` | Requires Authentication |

---

## Guest User Profile Configuration

Add to Apex Class Access:
- `RegistrationGuestController`
- `SelfRegistrationController`
- `MyRegistrationsController`

Object Permissions:
- Event__c: Read
- Venue__c: Read
- Attendee__c: Read, Create, Edit
- Registration__c: Read, Create, Edit

---

## Complete Class Reference

### Production Classes (12 total)

| # | Class | Lines | Purpose |
|---|-------|-------|---------|
| 1 | `RegistrationController` | ~80 | LWC controller for internal registration wizard. `getPublishedEvents()` + `registerForEvent()` with credit check |
| 2 | `RegistrationGuestController` | ~80 | Same logic, `without sharing` for guest/community users on LWR site |
| 3 | `SelfRegistrationController` | ~100 | User self-registration. Creates Contact → Attendee → Community User. Also handles `Site.login()` |
| 4 | `MyRegistrationsController` | ~60 | Gets user's registrations by email. Cancel method triggers waitlist promotion chain |
| 5 | `RegistrationService` | ~120 | Invocable method for bulk registration (can be used by Flows or APIs) |
| 6 | `RegistrationTriggerHandler` | ~90 | Before insert: credit validation + capacity/waitlist. After update: detect cancel → enqueue promotion |
| 7 | `CreditValidationService` | ~150 | Multi-currency credit validation. Converts amounts, sums exposure, compares to limit. Used by trigger + controllers |
| 8 | `PromoteWaitlistJob` | ~40 | Queueable: promotes top waitlisted registration when spot opens. Calls email service |
| 9 | `RegistrationEmailService` | ~40 | Sends "You're In!" email to promoted attendees |
| 10 | `BudgetApprovalController` | ~100 | Submit/Approve/Reject events. Finance permission check. Auto-approves ≤$10k |
| 11 | `EventTriggerHandler` | ~90 | Prevents venue double-booking (overlapping dates at same venue) |

### Test Classes (5 total)

| # | Class | Methods | Coverage |
|---|-------|---------|----------|
| 1 | `EventTriggerHandlerTest` | 5 | Double-booking scenarios |
| 2 | `RegistrationTriggerHandlerTest` | 5 | Capacity, waitlist, promotion |
| 3 | `RegistrationControllerTest` | 4 | Controller methods |
| 4 | `BudgetApprovalControllerTest` | 6 | Approval workflow |
| 5 | `CreditValidationServiceTest` | 10 | Credit checks + currency |

### Triggers (2 total)

| Trigger | Object | Events |
|---------|--------|--------|
| `EventTrigger` | Event__c | before insert, before update |
| `RegistrationTrigger` | Registration__c | before insert, after update |

---

## File Structure (Complete)

```
EpicEventz/
├── docs/
│   ├── COMPLETE_REFERENCE.md
│   ├── LWR_Site_Implementation.md      ← This file
│   ├── Phase1_Completion.md
│   ├── Phase2_Completion.md
│   ├── Phase2_Implementation_Guide.md
│   └── Phase3_Completion.md
├── force-app/main/default/
│   ├── applications/
│   │   └── EpicEventz.app-meta.xml
│   ├── classes/
│   │   ├── BudgetApprovalController.cls
│   │   ├── BudgetApprovalControllerTest.cls
│   │   ├── CreditValidationService.cls
│   │   ├── CreditValidationServiceTest.cls
│   │   ├── EventTriggerHandler.cls
│   │   ├── EventTriggerHandlerTest.cls
│   │   ├── MyRegistrationsController.cls        ← NEW
│   │   ├── PromoteWaitlistJob.cls
│   │   ├── RegistrationController.cls
│   │   ├── RegistrationControllerTest.cls
│   │   ├── RegistrationEmailService.cls
│   │   ├── RegistrationGuestController.cls
│   │   ├── RegistrationService.cls
│   │   ├── RegistrationTriggerHandler.cls
│   │   ├── RegistrationTriggerHandlerTest.cls
│   │   └── SelfRegistrationController.cls       ← NEW
│   ├── flexipages/
│   │   └── Event_Registration_Page.flexipage-meta.xml
│   ├── layouts/
│   │   ├── Attendee__c-Attendee Layout.layout-meta.xml
│   │   ├── Event__c-Event Layout.layout-meta.xml
│   │   ├── Registration__c-Registration Layout.layout-meta.xml
│   │   └── Venue__c-Venue Layout.layout-meta.xml
│   ├── lwc/
│   │   ├── budgetApproval/                      (internal finance)
│   │   ├── eventRegistration/                   (internal reg wizard)
│   │   ├── eventRegistrationPublic/             ← REBUILT (guest event listing)
│   │   ├── myRegistrations/                     ← NEW (user's bookings + cancel)
│   │   └── selfRegistration/                    ← NEW (login + signup)
│   ├── objects/ (Venue__c, Event__c, Attendee__c, Registration__c)
│   ├── permissionsets/ (Admin, Finance)
│   ├── tabs/ (4 custom tabs)
│   └── triggers/ (Event, Registration)
└── scripts/apex/
    ├── seedData.apex
    └── testAllPhases.apex
```

---

## What Happens When Someone Cancels (End-to-End)

```
1. User clicks "Cancel" on myRegistrations component
         ↓
2. Confirmation modal: "Are you sure?"
         ↓
3. User clicks "Yes, Cancel"
         ↓
4. MyRegistrationsController.cancelRegistration(regId)
         ↓
5. reg.Status__c = 'Cancelled'; update reg;
         ↓
6. RegistrationTrigger fires (after update)
         ↓
7. RegistrationTriggerHandler.handleAfterUpdate()
   detects: old='Confirmed', new='Cancelled'
         ↓
8. System.enqueueJob(new PromoteWaitlistJob({eventId}))
         ↓
9. PromoteWaitlistJob.execute():
   - Queries: SELECT ... WHERE Status='Waitlisted' ORDER BY Waitlist_Position ASC LIMIT 1
   - Sets: Status = 'Confirmed', Position = null
   - Database.update()
         ↓
10. RegistrationEmailService.sendPromotionEmails():
    - Queries full details (event name, attendee email)
    - Sends email: "You're In! Registration Confirmed - {Event}"
         ↓
11. UI refreshes (refreshApex) → cancelled reg disappears from list
12. Promoted user sees status change to "Confirmed" in their view
```

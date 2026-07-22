# EpicEventz — Complete Project Reference

**GitHub:** https://github.com/DamianDives/Epic-Eventz  
**Salesforce Org:** epicevents@gmail.com  
**Last Updated:** July 21, 2026  

---

## Table of Contents
1. [All Apex Classes & Their Purpose](#apex-classes)
2. [All LWC Components](#lwc-components)
3. [Triggers](#triggers)
4. [Objects & Fields](#objects)
5. [Page Layouts](#page-layouts)
6. [Permission Sets](#permission-sets)
7. [How Budget Approval Works](#budget-approval)
8. [How to Set Up the LWR Site](#lwr-site-setup)
9. [Changes Made in This Overhaul](#changes-log)

---

## Apex Classes

### Production Classes

| # | Class Name | Purpose | Called By |
|---|-----------|---------|-----------|
| 1 | **RegistrationController** | LWC controller for internal event registration. Gets published events, handles registration with capacity + credit checks | `eventRegistration` LWC |
| 2 | **RegistrationGuestController** | Same as above but `without sharing` — for guest/community users on LWR site. Allows unauthenticated registration | `eventRegistrationPublic` LWC |
| 3 | **RegistrationService** | Invocable Apex method for bulk registration. Can be called from Flows or other Apex. Handles attendee lookup/creation | Available for API/bulk use |
| 4 | **RegistrationTriggerHandler** | Trigger handler for Registration__c. Handles: (1) credit validation on insert, (2) auto-set Confirmed/Waitlisted status, (3) detect cancellation → enqueue promotion | `RegistrationTrigger` |
| 5 | **RegistrationEmailService** | Sends confirmation email when a waitlisted attendee gets promoted | `PromoteWaitlistJob` |
| 6 | **PromoteWaitlistJob** | Queueable job that promotes the top waitlisted person when a confirmed registration is cancelled | Enqueued by `RegistrationTriggerHandler` |
| 7 | **CreditValidationService** | Standalone credit validation with multi-currency conversion. Checks if an attendee's total registration exposure exceeds their credit limit | `RegistrationTriggerHandler`, `RegistrationController` |
| 8 | **BudgetApprovalController** | LWC controller for budget approval. Submit/Approve/Reject events. Only Finance permission holders can approve | `budgetApproval` LWC |
| 9 | **EventTriggerHandler** | Trigger handler for Event__c. Prevents venue double-booking (overlapping dates at same venue) | `EventTrigger` |

### Test Classes

| # | Class Name | Tests For | Methods |
|---|-----------|-----------|---------|
| 1 | **EventTriggerHandlerTest** | Double-booking prevention | 5 methods |
| 2 | **RegistrationTriggerHandlerTest** | Capacity/waitlist/promotion | 5 methods |
| 3 | **RegistrationControllerTest** | LWC controller methods | 4 methods |
| 4 | **BudgetApprovalControllerTest** | Approval workflow | 6 methods |
| 5 | **CreditValidationServiceTest** | Credit checks + currency conversion | 10 methods |

---

## LWC Components

### 1. eventRegistration (Internal Users)

**Location:** `force-app/main/default/lwc/eventRegistration/`  
**Used on:** Lightning App Pages, Record Pages, Home Page  
**Controller:** `RegistrationController.cls`

**Design:** Modern 3-step wizard with:
- Purple gradient hero header
- Progress stepper (Choose Event → Your Details → Confirmation)
- Card-based event selection grid with hover effects
- Clean form with 2-column layout
- Success/Error states with visual feedback

**Features:**
- Shows only Published events
- Auto-detects capacity → Confirmed or Waitlisted
- Credit validation before registration
- Responsive design (mobile-friendly)

### 2. eventRegistrationPublic (LWR Site / Guest Users)

**Location:** `force-app/main/default/lwc/eventRegistrationPublic/`  
**Used on:** Experience Cloud (LWR) site pages  
**Controller:** `RegistrationGuestController.cls` (without sharing)

**Same design as internal version but:**
- Uses `without sharing` controller (guest users have no record access)
- Exposed to `lightningCommunity__Page` and `lightningCommunity__Default`
- No authentication required to view events and register

### 3. budgetApproval (Finance Managers Only)

**Location:** `force-app/main/default/lwc/budgetApproval/`  
**Used on:** Lightning App Pages, Home Page  
**Controller:** `BudgetApprovalController.cls`

**Design:** Two-tab interface with datatable
- Tab 1: "Submit for Approval" — shows Draft events, submit action
- Tab 2: "Pending Approvals" — shows Pending events, approve/reject actions
- Confirmation modal with comments field
- Toast notifications for success/error

**Access Control:** Only users with `EpicEventz_Finance` permission set OR System Administrator profile can approve/reject.

---

## Triggers

| Trigger | Object | Events | Handler |
|---------|--------|--------|---------|
| `EventTrigger` | Event__c | before insert, before update | `EventTriggerHandler` |
| `RegistrationTrigger` | Registration__c | before insert, after update | `RegistrationTriggerHandler` |

---

## Objects & Fields

### Venue__c
| Field | Type | Purpose |
|-------|------|---------|
| Name | Auto Number (VEN-{0000}) | Unique venue identifier |
| Capacity__c | Number | Max people |
| Country__c | Text | |
| State__c | Text | |
| City__c | Text | |
| Venue_Type__c | Picklist | Indoor/Outdoor/Virtual/Hybrid |
| Address__c | Text Area | Full address |
| Active__c | Checkbox | Is venue available |

### Event__c
| Field | Type | Purpose |
|-------|------|---------|
| Name | Text | Event title |
| Event_Type__c | Picklist | Conference/Workshop/Seminar/Webinar/Meetup |
| Event_Status__c | Picklist | Draft/Published/Closed/Cancelled |
| Start_Date__c | DateTime | |
| End_Date__c | DateTime | |
| Budget__c | Currency | Total budget (Finance-only access) |
| Approved_Budget__c | Currency | Set on approval |
| Expected_Revenue__c | Currency | |
| Max_Capacity__c | Number | Seat limit |
| Approval_Status__c | Picklist | Pending/Approved/Rejected |
| Venue__c | Lookup(Venue__c) | |
| Total_Registrations__c | Roll-Up Summary | COUNT of registrations |
| Confirmed_Registrations__c | Roll-Up Summary | COUNT where Confirmed |
| Total_Revenue__c | Roll-Up Summary | SUM of Reg_Amount |
| Seats_Available__c | Formula | Max - Total |

### Attendee__c
| Field | Type | Purpose |
|-------|------|---------|
| Name | Text | Full name |
| Email__c | Email (Unique, External ID) | Primary identifier |
| Phone__c | Phone | |
| Company__c | Text | |
| Country__c | Text | |
| Credit_Limit__c | Currency | Max total spend (Finance-only) |
| Preferred_Currency__c | Picklist | USD/EUR/GBP/INR/AUD/CAD/JPY |
| VIP_Status__c | Checkbox | |
| Registration_Count__c | Roll-Up Summary | COUNT of registrations |

### Registration__c (Junction)
| Field | Type | Purpose |
|-------|------|---------|
| Name | Auto Number (REG-{00000}) | Registration number |
| Event__c | Master-Detail(Event__c) | |
| Attendee__c | Master-Detail(Attendee__c) | |
| Reg_Date__c | Date | When registered |
| Status__c | Picklist | Registered/Confirmed/Waitlisted/Cancelled |
| Reg_Amount__c | Currency | Fee paid |
| Converted_Amount__c | Currency | In attendee's preferred currency |
| Waitlist_Position__c | Number | Position in queue |
| Payment_Status__c | Picklist | Pending/Paid/Failed/Refunded |
| Credit_Validation_Status__c | Picklist | Pending/Passed/Failed |
| Waitlist_Status__c | Formula (Checkbox) | True if waitlisted |


---

## Page Layouts

All 4 objects now have proper page layouts with fields organized into sections:

| Layout | Sections |
|--------|----------|
| **Venue Layout** | Venue Information (type, capacity, active) + Location (country, state, city, address) + System Info |
| **Event Layout** | Event Details (name, type, status, dates, venue) + Capacity & Budget (max capacity, budget, approved budget) + Metrics (total regs, confirmed, revenue, seats) + System Info |
| **Attendee Layout** | Personal Info (name, email, phone, company) + Financial (credit limit, preferred currency, VIP) + Metrics (registration count) + System Info |
| **Registration Layout** | Registration Details (number, event, attendee, status) + Financial (date, amount, converted, payment status) + Waitlist & Credit (position, waitlist status, credit validation) + System Info |

---

## Permission Sets

| Permission Set | Who Gets It | Access |
|---------------|-------------|--------|
| **EpicEventz_Admin** | Admins, event managers | Full CRUD on all objects + all fields |
| **EpicEventz_Finance** | Finance managers ONLY | Budget__c, Approved_Budget__c, Credit_Limit__c + ability to approve/reject budgets |

---

## Budget Approval — How It Works

1. **Event is created** in Draft status
2. **User submits** via the `budgetApproval` LWC → "Submit for Approval" tab
3. **System checks budget:**
   - Budget ≤ $10,000 → **Auto-approved** (status = Published immediately)
   - Budget > $10,000 → **Set to Pending** (awaits Finance Manager)
4. **Finance Manager** opens `budgetApproval` LWC → "Pending Approvals" tab
5. **Clicks Approve or Reject:**
   - Approve → Approval_Status = Approved, Approved_Budget = Budget, Event_Status = Published
   - Reject → Approval_Status = Rejected, Event_Status = Draft
6. **Only Finance** (EpicEventz_Finance permission set or System Admin) can approve/reject. Others get: "Access denied. Only Finance Managers can approve budgets."

---

## How to Set Up the LWR Site

These steps require manual Setup in your Salesforce org:

### Step 1: Enable Digital Experiences
1. Setup → **Digital Experiences** → **Settings**
2. Check "Enable Digital Experiences"
3. Click Save

### Step 2: Create the LWR Site
1. Setup → **Digital Experiences** → **All Sites** → **New**
2. Choose **Build Your Own (LWR)** template
3. Site name: `EpicEventz`
4. URL: `/epiceventz`
5. Click Create

### Step 3: Add the Registration Component
1. In **Experience Builder**, go to the Home page
2. Drag `eventRegistrationPublic` from the Components panel onto the page
3. Save and **Publish**

### Step 4: Enable Guest Access
1. In Experience Builder → Settings → **General**
2. Enable "Allow guest users to access public pages"
3. Go to **Administration** → **Pages** → set Home as public

### Step 5: Grant Guest User Object Access
1. Setup → **Digital Experiences** → your site → **Administration** → **Preferences**
2. Check "Allow guest users to access the site"
3. Go to **Guest User Profile** → edit
4. Grant Read access to: Event__c, Venue__c
5. Grant Create access to: Attendee__c, Registration__c
6. Ensure `RegistrationGuestController` is in the Guest Profile's Apex Class Access

### Step 6: Enable Self-Registration (for login)
1. Experience Builder → **Administration** → **Login & Registration**
2. Enable "Allow external users to self-register"
3. Choose a Profile (Customer Community User)
4. Set the registration page

---

## Changes Made in This Overhaul

| # | Change | What Was Wrong | What Was Fixed |
|---|--------|---------------|----------------|
| 1 | **eventRegistration LWC redesigned** | Basic SLDS cards, looked generic | Modern gradient design, card grid, progress stepper, custom CSS |
| 2 | **Page layouts created** | Empty/nonexistent layouts | Full layouts for all 4 objects with logical field grouping |
| 3 | **Custom tabs created** | No tabs for custom objects | Tabs for Venue, Event, Attendee, Registration |
| 4 | **EpicEventz Lightning App** | No app for navigation | Custom app with all 4 tabs |
| 5 | **Budget approval role-restricted** | Anyone could approve | Only Finance permission set holders can approve/reject |
| 6 | **eventRegistrationPublic LWC** | No public/guest component | New LWC with `without sharing` controller for LWR site |
| 7 | **RegistrationGuestController** | No guest controller | New class running without sharing for community users |
| 8 | **Venue layout Name field** | Marked Required (invalid for Auto Number) | Changed to Readonly |

---

## File Structure (Final)

```
EpicEventz/
├── docs/
│   ├── COMPLETE_REFERENCE.md          ← This file
│   ├── Phase1_Completion.md
│   ├── Phase2_Completion.md
│   ├── Phase2_Implementation_Guide.md
│   └── Phase3_Completion.md
├── force-app/main/default/
│   ├── applications/
│   │   └── EpicEventz.app-meta.xml
│   ├── classes/
│   │   ├── BudgetApprovalController.cls (+meta)
│   │   ├── BudgetApprovalControllerTest.cls (+meta)
│   │   ├── CreditValidationService.cls (+meta)
│   │   ├── CreditValidationServiceTest.cls (+meta)
│   │   ├── EventTriggerHandler.cls (+meta)
│   │   ├── EventTriggerHandlerTest.cls (+meta)
│   │   ├── PromoteWaitlistJob.cls (+meta)
│   │   ├── RegistrationController.cls (+meta)
│   │   ├── RegistrationControllerTest.cls (+meta)
│   │   ├── RegistrationEmailService.cls (+meta)
│   │   ├── RegistrationGuestController.cls (+meta)
│   │   ├── RegistrationService.cls (+meta)
│   │   ├── RegistrationTriggerHandler.cls (+meta)
│   │   └── RegistrationTriggerHandlerTest.cls (+meta)
│   ├── flexipages/
│   │   └── Event_Registration_Page.flexipage-meta.xml
│   ├── layouts/
│   │   ├── Attendee__c-Attendee Layout.layout-meta.xml
│   │   ├── Event__c-Event Layout.layout-meta.xml
│   │   ├── Registration__c-Registration Layout.layout-meta.xml
│   │   └── Venue__c-Venue Layout.layout-meta.xml
│   ├── lwc/
│   │   ├── budgetApproval/
│   │   ├── eventRegistration/
│   │   └── eventRegistrationPublic/
│   ├── objects/ (Venue__c, Event__c, Attendee__c, Registration__c)
│   ├── permissionsets/
│   │   ├── EpicEventz_Admin.permissionset-meta.xml
│   │   └── EpicEventz_Finance.permissionset-meta.xml
│   ├── tabs/ (Venue__c, Event__c, Attendee__c, Registration__c)
│   ├── triggers/
│   │   ├── EventTrigger.trigger (+meta)
│   │   └── RegistrationTrigger.trigger (+meta)
│   └── objects/Event__c/validationRules/
│       └── Max_Capacity_Exceeds_Venue.validationRule-meta.xml
└── scripts/apex/
    ├── seedData.apex
    └── testAllPhases.apex
```

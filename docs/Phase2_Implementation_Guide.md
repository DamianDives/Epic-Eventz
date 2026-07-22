# Phase 2 — Full Implementation Guide

**Project:** EpicEventz  
**Approach:** LWC + Apex (No declarative Flows)  
**Completed:** July 21, 2026  

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        USER INTERFACE                             │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐     │
│  │         eventRegistration LWC (3-step wizard)            │     │
│  │  Step 1: Select Event → Step 2: Form → Step 3: Result   │     │
│  └──────────────────────────┬──────────────────────────────┘     │
│                             │ @wire / imperative call             │
└─────────────────────────────┼───────────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────────┐
│                      APEX CONTROLLER                              │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐     │
│  │  RegistrationController.cls                              │     │
│  │  • getPublishedEvents() — @AuraEnabled(cacheable=true)   │     │
│  │  • registerForEvent()   — @AuraEnabled                   │     │
│  └──────────────────────────┬──────────────────────────────┘     │
│                             │ insert Registration__c              │
└─────────────────────────────┼───────────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────────┐
│                      TRIGGER LAYER                                │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐     │
│  │  RegistrationTrigger.trigger                             │     │
│  │  • before insert → RegistrationTriggerHandler            │     │
│  │  • after update  → RegistrationTriggerHandler            │     │
│  └──────────────────────────┬──────────────────────────────┘     │
│                             │                                     │
│  ┌─────────────────────────────────────────────────────────┐     │
│  │  RegistrationTriggerHandler.cls                          │     │
│  │  • handleBeforeInsert() — capacity/waitlist logic        │     │
│  │  • handleAfterUpdate()  — detect cancellation            │     │
│  └──────────────────────────┬──────────────────────────────┘     │
│                             │ System.enqueueJob()                 │
└─────────────────────────────┼───────────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────────┐
│                      ASYNC LAYER                                  │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐     │
│  │  PromoteWaitlistJob.cls (Queueable)                      │     │
│  │  • Finds top waitlisted registration                     │     │
│  │  • Promotes to Confirmed                                 │     │
│  │  • Calls RegistrationEmailService                        │     │
│  └──────────────────────────┬──────────────────────────────┘     │
│                             │                                     │
│  ┌─────────────────────────────────────────────────────────┐     │
│  │  RegistrationEmailService.cls                            │     │
│  │  • Sends promotion confirmation email                    │     │
│  └─────────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────────┘
```

---

## Component 1: eventRegistration LWC

### What It Does
A 3-step registration wizard that runs inside Lightning pages or Experience Cloud (LWR) sites.

### Step-by-Step Flow

**Step 1 — Select Event:**
- On load, the `@wire(getPublishedEvents)` decorator calls the Apex controller
- Returns all Event__c records where Event_Status__c = 'Published'
- Events are displayed as clickable cards showing name, venue, dates, capacity
- User clicks a card → it gets highlighted with a blue border
- "Next" button is disabled until an event is selected

**Step 2 — Attendee Information:**
- Form fields: Full Name (required), Email (required), Phone, Company, Registration Amount (required)
- Uses `lightning-input` with built-in validation (email format, required fields)
- "Back" button returns to Step 1
- "Register" button triggers `handleRegister()`

**Step 3 — Confirmation:**
- Shows success (green) or error (red) banner
- On success: displays Registration # (auto-number like REG-00001), Status badge (Confirmed/Waitlisted), and waitlist position if applicable
- "Register Another" resets everything to Step 1

### Key JavaScript Logic

```javascript
// Wire service — automatically calls Apex when component loads
@wire(getPublishedEvents)
wiredEvents({ error, data }) { ... }

// Imperative call — user clicks Register
async handleRegister() {
    // 1. Validate all inputs
    // 2. Call registerForEvent() imperatively
    // 3. Display result on Step 3
}
```

### Where It Can Be Used
Defined in `eventRegistration.js-meta.xml`:
- `lightning__AppPage` — standalone Lightning App pages
- `lightning__RecordPage` — on Event__c record pages
- `lightning__HomePage` — org home page
- `lightningCommunity__Page` — Experience Cloud pages
- `lightningCommunity__Default` — LWR site default pages

---

## Component 2: RegistrationController.cls

### Method: getPublishedEvents()

```apex
@AuraEnabled(cacheable=true)
public static List<Event__c> getPublishedEvents()
```

- **Cacheable:** Yes — results are cached client-side, reducing server calls
- **Query:** All Event__c where Status = Published, ordered by Start_Date ascending
- **Returns:** Event name, type, dates, capacity, venue info (city + state via relationship)

### Method: registerForEvent()

```apex
@AuraEnabled
public static RegistrationResult registerForEvent(
    String eventId, String attendeeName, String email, 
    String phone, String company, Decimal regAmount
)
```

**Logic flow:**

1. **Find or create attendee:**
   ```apex
   List<Attendee__c> existing = [SELECT Id FROM Attendee__c WHERE Email__c = :email];
   if (existing.isEmpty()) {
       // Create new Attendee__c
       insert newAttendee;
   }
   ```

2. **Check capacity:**
   ```apex
   Integer confirmedCount = [SELECT COUNT() FROM Registration__c 
                             WHERE Event__c = :eventId AND Status__c = 'Confirmed'];
   Decimal maxCap = evt.Max_Capacity__c;
   ```

3. **Set status:**
   ```apex
   if (confirmedCount < maxCap) {
       reg.Status__c = 'Confirmed';       // Under capacity
   } else {
       reg.Status__c = 'Waitlisted';      // At/over capacity
       reg.Waitlist_Position__c = waitlistCount + 1;
   }
   ```

4. **Insert registration and return result** (including the auto-number REG-XXXXX)

### Why the Controller Pre-Sets Status
The controller sets 'Confirmed' or 'Waitlisted' BEFORE the insert. The trigger's `handleBeforeInsert` only processes records with Status = 'Registered' or null. This prevents double-processing — the controller owns the logic for LWC-originated registrations, the trigger handles direct API/Data Loader inserts.

---

## Component 3: RegistrationTrigger + Handler

### Trigger Events

| Event | Handler Method | Purpose |
|-------|---------------|---------|
| `before insert` | `handleBeforeInsert()` | Auto-set status for direct inserts |
| `after update` | `handleAfterUpdate()` | Detect cancellation → promote waitlist |

### handleBeforeInsert — Capacity Logic

This only fires for registrations where Status = 'Registered' or null (i.e., NOT from the LWC controller which pre-sets the status).

**Bulkification pattern:**
```
1. Collect all Event IDs from incoming records
2. ONE query: count confirmed registrations per event
3. ONE query: count waitlisted registrations per event
4. Track batch-level increments (Map<Id, Integer>)
5. For each record: check capacity, set status
```

**Why batch tracking matters:**
If 10 registrations are inserted at once for an event with 5 remaining seats, the handler tracks how many it's already confirmed in this batch. Without this, all 10 would get 'Confirmed' (because the COUNT query returns the same number for all of them).

```apex
Integer confirmed = batchConfirmed.get(reg.Event__c); // How many already confirmed in THIS batch
Integer currentRegs = existingConfirmed + confirmed;   // Total = DB + batch
if (currentRegs < maxCap) {
    reg.Status__c = 'Confirmed';
    batchConfirmed.put(reg.Event__c, confirmed + 1);   // Increment batch counter
}
```

### handleAfterUpdate — Cancellation Detection

```apex
for (Registration__c reg : newRegs) {
    Registration__c oldReg = oldMap.get(reg.Id);
    if (oldReg.Status__c == 'Confirmed' && reg.Status__c == 'Cancelled') {
        eventIdsToPromote.add(reg.Event__c);
    }
}
// Enqueue async job to promote waitlist
System.enqueueJob(new PromoteWaitlistJob(eventIdsToPromote));
```

---

## Component 4: PromoteWaitlistJob (Queueable)

### Why Queueable (not synchronous)?
- Avoids governor limits within the trigger transaction
- Runs in its own execution context with fresh limits
- Can chain further async work if needed
- Avoids mixed DML issues

### Logic:
```apex
public void execute(QueueableContext context) {
    for (Id eventId : eventIds) {
        // Get the #1 waitlisted person (lowest position number)
        Registration__c topWaitlisted = [
            SELECT Id FROM Registration__c
            WHERE Event__c = :eventId AND Status__c = 'Waitlisted'
            ORDER BY Waitlist_Position__c ASC LIMIT 1
        ];
        
        topWaitlisted.Status__c = 'Confirmed';
        topWaitlisted.Waitlist_Position__c = null;
        toPromote.add(topWaitlisted);
    }
    
    Database.update(toPromote, AccessLevel.SYSTEM_MODE);
    RegistrationEmailService.sendPromotionEmails(toPromote);
}
```

**AccessLevel.SYSTEM_MODE** — bypasses field-level security so the job can update Status__c regardless of the running user's permissions.

---

## Component 5: RegistrationEmailService

### When It Fires
Only when a waitlisted attendee gets promoted to Confirmed (called by PromoteWaitlistJob).

### Email Sent:
- **To:** Attendee's email address
- **Subject:** "You're In! Registration Confirmed - {Event Name}"
- **Body:** Congratulatory message with event dates
- **Failure handling:** `Messaging.sendEmail(emails, false)` — won't crash if delivery fails

---

## End-to-End Scenarios

### Scenario 1: Normal Registration (Under Capacity)

```
User opens LWC → sees published events
   ↓
Clicks "Tech Summit 2025" → clicks Next
   ↓
Fills in name, email, amount → clicks Register
   ↓
RegistrationController.registerForEvent() called
   ↓
Checks: confirmedCount (4) < maxCapacity (400) ✅
   ↓
Sets Status = 'Confirmed', inserts Registration__c
   ↓
Trigger fires (before insert) → sees Status is already 'Confirmed' → SKIPS
   ↓
Returns: { success: true, status: 'Confirmed', regNumber: 'REG-00011' }
   ↓
LWC shows: ✅ "You're confirmed! See you at the event."
```

### Scenario 2: Event Full (Waitlisted)

```
User registers for event at max capacity (400/400 confirmed)
   ↓
RegistrationController checks: confirmedCount (400) >= maxCapacity (400) ❌
   ↓
Sets Status = 'Waitlisted', Waitlist_Position = 3 (two already waiting)
   ↓
Returns: { success: true, status: 'Waitlisted', waitlistPosition: 3 }
   ↓
LWC shows: "You've been added to the waitlist. Position: 3"
```

### Scenario 3: Cancellation → Auto-Promotion

```
Admin changes a confirmed registration's Status to 'Cancelled'
   ↓
RegistrationTrigger fires (after update)
   ↓
Handler detects: old='Confirmed', new='Cancelled' → adds Event ID
   ↓
System.enqueueJob(new PromoteWaitlistJob({eventId}))
   ↓
Queueable executes (async, seconds later):
   ↓
Queries: SELECT ... WHERE Status = 'Waitlisted' ORDER BY Waitlist_Position ASC LIMIT 1
   ↓
Updates that registration: Status → 'Confirmed', Position → null
   ↓
RegistrationEmailService sends email:
   "Dear John, Great news! A spot has opened up..."
```

### Scenario 4: Bulk Insert via Data Loader (200 records)

```
Data Loader inserts 200 Registration__c with Status = 'Registered'
   ↓
RegistrationTrigger fires (before insert) — all 200 records
   ↓
Handler: queries confirmed count (say 350, capacity 400)
   ↓
First 50 records → set 'Confirmed' (batch counter: 1, 2, ... 50)
   ↓
At record 51: existingConfirmed(350) + batchConfirmed(50) = 400 = maxCap
   ↓
Records 51-200 → set 'Waitlisted' with positions 1, 2, 3...150
   ↓
All 200 records save successfully in one transaction
```

---

## File Structure

```
force-app/main/default/
├── lwc/
│   └── eventRegistration/
│       ├── eventRegistration.html       ← UI template (3 steps)
│       ├── eventRegistration.js         ← Logic (wire, handlers, validation)
│       ├── eventRegistration.css        ← Card hover/selection styles
│       └── eventRegistration.js-meta.xml ← Exposed to App/Record/Community pages
├── classes/
│   ├── RegistrationController.cls       ← LWC Apex controller
│   ├── RegistrationController.cls-meta.xml
│   ├── RegistrationTriggerHandler.cls   ← Trigger logic (capacity + promotion)
│   ├── RegistrationTriggerHandler.cls-meta.xml
│   ├── PromoteWaitlistJob.cls           ← Async waitlist promotion
│   ├── PromoteWaitlistJob.cls-meta.xml
│   ├── RegistrationEmailService.cls     ← Email notifications
│   ├── RegistrationEmailService.cls-meta.xml
│   ├── RegistrationService.cls          ← Invocable (kept for API/bulk use)
│   ├── RegistrationService.cls-meta.xml
│   ├── RegistrationControllerTest.cls   ← Controller tests
│   ├── RegistrationControllerTest.cls-meta.xml
│   ├── RegistrationTriggerHandlerTest.cls ← Trigger tests
│   └── RegistrationTriggerHandlerTest.cls-meta.xml
├── triggers/
│   ├── RegistrationTrigger.trigger
│   └── RegistrationTrigger.trigger-meta.xml
└── flexipages/
    └── Event_Registration_Page.flexipage-meta.xml  ← App page with LWC
```

---

## How to Access the LWC in Your Org

The `Event_Registration_Page.flexipage` is already deployed. To make it visible:

1. Open your org (App Launcher)
2. Go to **Setup → App Builder** → you'll see "Event Registration Page"
3. Click **Activate** → choose which app/profiles see it
4. Or: Go to any Lightning App → **Edit** → add the page to navigation

For LWR Experience Site (later in Phase 7):
- The LWC is exposed to `lightningCommunity__Page` and `lightningCommunity__Default`
- Drop it directly onto any LWR page in Experience Builder

---

## Tests Passing

| Test Class | Methods | Status |
|-----------|---------|--------|
| RegistrationControllerTest | 4 methods | ✅ All pass |
| RegistrationTriggerHandlerTest | 5 methods | ✅ All pass |
| EventTriggerHandlerTest | 5 methods | ✅ All pass |

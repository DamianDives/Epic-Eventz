# Phase 1 — Core Schema: Completion Report

**Project:** EpicEventz  
**Org:** epicevents@gmail.com (Trailhead Playground)  
**Completed:** July 21, 2026  

---

## Overview

Phase 1 establishes the five-object data model, relationships, roll-up summaries, formulas, an Apex trigger for venue double-booking prevention, a declarative validation rule for capacity checking, and seed sample data.

---

## Objects Created

### 1. Venue__c
| Field | Type | Notes |
|-------|------|-------|
| Name (Venue_Code) | Auto Number | Format: VEN-{0000} |
| Capacity__c | Number(18,0) | Max people the venue holds |
| Country__c | Text(255) | |
| State__c | Text(255) | |
| City__c | Text(255) | |
| Venue_Type__c | Picklist | Indoor, Outdoor, Virtual, Hybrid |
| Address__c | Text Area(255) | |
| Active__c | Checkbox | Default: true |

### 2. Event__c
| Field | Type | Notes |
|-------|------|-------|
| Name | Text | Event name |
| Event_Type__c | Picklist | Conference, Workshop, Seminar, Webinar, Meetup |
| Event_Status__c | Picklist | Draft, Published, Closed, Cancelled |
| Start_Date__c | DateTime | |
| End_Date__c | DateTime | |
| Budget__c | Currency(16,2) | |
| Expected_Revenue__c | Currency(16,2) | |
| Approved_Budget__c | Currency(16,2) | |
| Max_Capacity__c | Number(18,0) | |
| Approval_Status__c | Picklist | Pending, Approved, Rejected |
| Venue__c | Lookup(Venue__c) | Not Master-Detail — event can exist without a venue |
| Total_Registrations__c | Roll-Up Summary | COUNT of Registration__c |
| Confirmed_Registrations__c | Roll-Up Summary | COUNT where Status = Confirmed |
| Total_Revenue__c | Roll-Up Summary | SUM of Reg_Amount__c |
| Seats_Available__c | Formula (Number) | Max_Capacity__c - Total_Registrations__c |

### 3. Attendee__c
| Field | Type | Notes |
|-------|------|-------|
| Name | Text | Attendee full name |
| Email__c | Email | External ID + Unique |
| Phone__c | Phone | |
| Company__c | Text(255) | |
| Country__c | Text(255) | |
| Credit_Limit__c | Currency(16,2) | |
| Preferred_Currency__c | Picklist | USD, EUR, GBP, INR, AUD, CAD, JPY |
| VIP_Status__c | Checkbox | |
| Registration_Count__c | Roll-Up Summary | COUNT of Registration__c |

### 4. Registration__c (Junction Object)
| Field | Type | Notes |
|-------|------|-------|
| Name (Reg_Number) | Auto Number | Format: REG-{00000} |
| Event__c | Master-Detail(Event__c) | Primary relationship |
| Attendee__c | Master-Detail(Attendee__c) | Secondary relationship |
| Reg_Date__c | Date | |
| Status__c | Picklist | Registered, Confirmed, Waitlisted, Cancelled |
| Reg_Amount__c | Currency(16,2) | |
| Converted_Amount__c | Currency(16,2) | For multi-currency (Phase 4) |
| Waitlist_Position__c | Number(18,0) | |
| Payment_Status__c | Picklist | Pending, Paid, Failed, Refunded |
| Credit_Validation_Status__c | Picklist | Pending, Passed, Failed |
| Waitlist_Status__c | Formula (Checkbox) | TRUE if Status = Waitlisted |

---

## Automation

### Apex Trigger: Venue Double-Booking Prevention

**Files:**
- `force-app/main/default/triggers/EventTrigger.trigger`
- `force-app/main/default/classes/EventTriggerHandler.cls`

**Behavior:**
- Fires on `before insert` and `before update` of Event__c
- Prevents two events from being booked at the same venue with overlapping dates
- Overlap logic: `Event1.Start < Event2.End AND Event1.End > Event2.Start`
- Bulkified: handles 200+ records in a single transaction
- Checks both existing DB records AND records within the same trigger batch
- Error message: "This venue is already booked for the selected dates. Please choose different dates or a different venue."

**Optimization:**
- Only checks records where Venue, Start_Date, or End_Date actually changed (on update)
- Single SOQL query for all venues in the batch
- In-memory overlap detection

### Validation Rule: Max_Capacity_Exceeds_Venue

**File:** `force-app/main/default/objects/Event__c/validationRules/Max_Capacity_Exceeds_Venue.validationRule-meta.xml`

**Formula:**
```
AND(
  NOT(ISBLANK(Venue__c)),
  NOT(ISBLANK(Max_Capacity__c)),
  Max_Capacity__c > Venue__r.Capacity__c
)
```

**Error:** "Event Max Capacity cannot exceed the Venue capacity." (shown on Max_Capacity__c field)

---

## Test Coverage

**File:** `force-app/main/default/classes/EventTriggerHandlerTest.cls`

| Test Method | Scenario | Result |
|------------|----------|--------|
| testInsertEventAtVenue_ShouldSucceed | Insert with no overlap | ✅ Pass |
| testInsertOverlappingEvent_ShouldFail | Overlapping dates at same venue | ✅ Pass |
| testInsertNonOverlappingEvent_ShouldSucceed | Non-overlapping at same venue | ✅ Pass |
| testUpdateEventToOverlap_ShouldFail | Update dates to cause overlap | ✅ Pass |
| testBulkInsert_MixedOverlaps | Bulk insert with mixed results | ✅ Pass |

All 5 tests passing. Coverage meets the 75% minimum for production deployment.

---

## Seed Data

**Script:** `scripts/apex/seedData.apex`

| Object | Records | Examples |
|--------|---------|----------|
| Venue__c | 3 | San Francisco (500 cap), NYC (200), London (1000) |
| Event__c | 5 | Tech Summit, AI Workshop, Cloud Seminar, DevOps Meetup, Bootcamp |
| Attendee__c | 12 | Mix of US, UK, India, Japan, France, Australia, Mexico |
| Registration__c | 10 | Confirmed and Registered statuses, various amounts |

---

## Permission Set

**EpicEventz_Admin** — Full CRUD and field-level access on all four custom objects. Assigned to admin user.

---

## Phase 1 Exit Criteria — MET ✅

- [x] Venue created with all fields
- [x] Event linked to Venue via lookup
- [x] Attendee created with unique email
- [x] Registration (junction) links Event + Attendee
- [x] Roll-ups on Event update correctly when Registration created
- [x] Double-booking prevented by Apex trigger
- [x] Capacity validation rule blocks over-capacity events
- [x] Tests pass at ≥75% coverage
- [x] Seed data loaded for Phase 2 testing

---

## File Structure

```
EpicEventz/
├── force-app/main/default/
│   ├── objects/
│   │   ├── Venue__c/
│   │   ├── Event__c/
│   │   │   └── validationRules/Max_Capacity_Exceeds_Venue.validationRule-meta.xml
│   │   ├── Attendee__c/
│   │   └── Registration__c/
│   ├── triggers/
│   │   └── EventTrigger.trigger
│   ├── classes/
│   │   ├── EventTriggerHandler.cls
│   │   └── EventTriggerHandlerTest.cls
│   └── permissionsets/
│       └── EpicEventz_Admin.permissionset-meta.xml
└── scripts/apex/
    └── seedData.apex
```

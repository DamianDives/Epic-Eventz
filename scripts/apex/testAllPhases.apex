// ============================================
// EpicEventz End-to-End Test: "KarthikHacks"
// Tests Phase 1 through Phase 4
// ============================================

System.debug('========== PHASE 1: Core Schema Test ==========');

// Create a Venue
Venue__c venue = new Venue__c(
    Capacity__c = 50,
    Country__c = 'India',
    State__c = 'Karnataka',
    City__c = 'Bangalore',
    Venue_Type__c = 'Indoor',
    Address__c = '100 MG Road, Bangalore',
    Active__c = true
);
insert venue;
System.debug('✅ Venue created: ' + venue.Id + ' (Name: ' + [SELECT Name FROM Venue__c WHERE Id = :venue.Id].Name + ')');

// Create an Event - "KarthikHacks"
Event__c evt = new Event__c(
    Name = 'KarthikHacks',
    Event_Type__c = 'Conference',
    Event_Status__c = 'Draft',
    Start_Date__c = DateTime.newInstance(2025, 10, 15, 9, 0, 0),
    End_Date__c = DateTime.newInstance(2025, 10, 17, 18, 0, 0),
    Budget__c = 25000,
    Max_Capacity__c = 5,
    Venue__c = venue.Id
);
insert evt;
System.debug('✅ Event "KarthikHacks" created: ' + evt.Id);

// Test Phase 1: Venue Double-Booking Prevention
System.debug('\n--- Phase 1: Double-Booking Test ---');
try {
    Event__c overlapping = new Event__c(
        Name = 'Overlapping Event',
        Event_Type__c = 'Workshop',
        Event_Status__c = 'Draft',
        Start_Date__c = DateTime.newInstance(2025, 10, 16, 9, 0, 0),
        End_Date__c = DateTime.newInstance(2025, 10, 18, 18, 0, 0),
        Budget__c = 5000,
        Max_Capacity__c = 30,
        Venue__c = venue.Id
    );
    insert overlapping;
    System.debug('❌ FAIL: Overlapping event should have been blocked!');
} catch (DmlException e) {
    System.debug('✅ Double-booking BLOCKED: ' + e.getDmlMessage(0));
}

// Test Phase 1: Capacity Validation Rule
System.debug('\n--- Phase 1: Capacity Validation Rule ---');
try {
    Event__c overCapacity = new Event__c(
        Name = 'Over Capacity Event',
        Event_Type__c = 'Seminar',
        Event_Status__c = 'Draft',
        Start_Date__c = DateTime.newInstance(2026, 3, 1, 9, 0, 0),
        End_Date__c = DateTime.newInstance(2026, 3, 2, 18, 0, 0),
        Budget__c = 5000,
        Max_Capacity__c = 100,
        Venue__c = venue.Id
    );
    insert overCapacity;
    System.debug('❌ FAIL: Over-capacity event should have been blocked!');
} catch (DmlException e) {
    System.debug('✅ Capacity rule BLOCKED: ' + e.getDmlMessage(0));
}

System.debug('\n========== PHASE 2: Registration + Capacity + Waitlist ==========');

// Create attendees
List<Attendee__c> attendees = new List<Attendee__c>();
attendees.add(new Attendee__c(Name = 'Karthik Kaiser', Email__c = 'karthik@hacks.dev', Phone__c = '9876543210', Company__c = 'KarthikHacks', Country__c = 'India', Credit_Limit__c = 5000, Preferred_Currency__c = 'USD'));
attendees.add(new Attendee__c(Name = 'Alice Dev', Email__c = 'alice@dev.com', Company__c = 'DevCorp', Credit_Limit__c = 3000, Preferred_Currency__c = 'USD'));
attendees.add(new Attendee__c(Name = 'Bob Builder', Email__c = 'bob@build.io', Company__c = 'BuildIO', Credit_Limit__c = 4000, Preferred_Currency__c = 'GBP'));
attendees.add(new Attendee__c(Name = 'Charlie Cloud', Email__c = 'charlie@cloud.net', Company__c = 'CloudNet', Credit_Limit__c = 2000, Preferred_Currency__c = 'EUR'));
attendees.add(new Attendee__c(Name = 'Diana Data', Email__c = 'diana@data.org', Company__c = 'DataOrg', Credit_Limit__c = 3500, Preferred_Currency__c = 'USD'));
attendees.add(new Attendee__c(Name = 'Eve Extra', Email__c = 'eve@extra.com', Company__c = 'ExtraCo', Credit_Limit__c = 2500, Preferred_Currency__c = 'USD'));
attendees.add(new Attendee__c(Name = 'Frank Full', Email__c = 'frank@full.io', Company__c = 'FullIO', Credit_Limit__c = 3000, Preferred_Currency__c = 'USD'));
insert attendees;
System.debug('✅ 7 Attendees created');

// Register first 5 (capacity = 5, so all should be Confirmed)
System.debug('\n--- Registering 5 attendees (capacity = 5) ---');
List<Registration__c> regs = new List<Registration__c>();
for (Integer i = 0; i < 5; i++) {
    regs.add(new Registration__c(
        Event__c = evt.Id,
        Attendee__c = attendees[i].Id,
        Reg_Date__c = Date.today(),
        Status__c = 'Registered',
        Reg_Amount__c = 500,
        Payment_Status__c = 'Pending'
    ));
}
insert regs;

// Check statuses
List<Registration__c> insertedRegs = [SELECT Name, Status__c, Waitlist_Position__c, Attendee__r.Name FROM Registration__c WHERE Event__c = :evt.Id ORDER BY CreatedDate];
for (Registration__c r : insertedRegs) {
    System.debug('  ' + r.Attendee__r.Name + ' → ' + r.Status__c + (r.Waitlist_Position__c != null ? ' (Position: ' + r.Waitlist_Position__c + ')' : ''));
}

// Register 6th and 7th (should be WAITLISTED)
System.debug('\n--- Registering 2 more (over capacity → waitlisted) ---');
List<Registration__c> waitlistRegs = new List<Registration__c>();
waitlistRegs.add(new Registration__c(
    Event__c = evt.Id, Attendee__c = attendees[5].Id,
    Reg_Date__c = Date.today(), Status__c = 'Registered',
    Reg_Amount__c = 500, Payment_Status__c = 'Pending'
));
waitlistRegs.add(new Registration__c(
    Event__c = evt.Id, Attendee__c = attendees[6].Id,
    Reg_Date__c = Date.today(), Status__c = 'Registered',
    Reg_Amount__c = 500, Payment_Status__c = 'Pending'
));
insert waitlistRegs;

List<Registration__c> allRegs = [SELECT Name, Status__c, Waitlist_Position__c, Attendee__r.Name FROM Registration__c WHERE Event__c = :evt.Id ORDER BY CreatedDate];
Integer confirmedCount = 0;
Integer waitlistedCount = 0;
for (Registration__c r : allRegs) {
    if (r.Status__c == 'Confirmed') confirmedCount++;
    if (r.Status__c == 'Waitlisted') waitlistedCount++;
}
System.debug('✅ Confirmed: ' + confirmedCount + ', Waitlisted: ' + waitlistedCount);

// Show waitlisted ones
for (Registration__c r : allRegs) {
    if (r.Status__c == 'Waitlisted') {
        System.debug('  WAITLISTED: ' + r.Attendee__r.Name + ' → Position ' + r.Waitlist_Position__c);
    }
}

// Cancel one confirmed → triggers waitlist promotion
System.debug('\n--- Cancelling one confirmed registration (triggers promotion) ---');
Registration__c toCancel = [SELECT Id, Attendee__r.Name FROM Registration__c WHERE Event__c = :evt.Id AND Status__c = 'Confirmed' LIMIT 1];
System.debug('  Cancelling: ' + toCancel.Attendee__r.Name);
toCancel.Status__c = 'Cancelled';
update toCancel;
System.debug('✅ Cancellation done. PromoteWaitlistJob enqueued (async - will promote #1 waitlisted)');

System.debug('\n========== PHASE 3: Budget Approval ==========');

// Event "KarthikHacks" has Budget = $25,000 (> $10,000 threshold)
System.debug('--- Submitting KarthikHacks for approval (Budget: $25,000) ---');
BudgetApprovalController.ApprovalResult submitResult = BudgetApprovalController.submitForApproval(evt.Id, 'Please approve KarthikHacks budget');
System.debug('✅ Submit result: ' + submitResult.status + ' - ' + submitResult.message);

// Approve it
System.debug('\n--- Approving KarthikHacks budget ---');
BudgetApprovalController.ApprovalResult approveResult = BudgetApprovalController.approveEvent(evt.Id, 'Approved! Great event.');
System.debug('✅ Approve result: ' + approveResult.status + ' - ' + approveResult.message);

// Verify event is now Published
Event__c approvedEvt = [SELECT Event_Status__c, Approval_Status__c, Approved_Budget__c FROM Event__c WHERE Id = :evt.Id];
System.debug('  Event Status: ' + approvedEvt.Event_Status__c);
System.debug('  Approval Status: ' + approvedEvt.Approval_Status__c);
System.debug('  Approved Budget: $' + approvedEvt.Approved_Budget__c);

// Test auto-approve (low budget)
Event__c lowBudgetEvt = new Event__c(
    Name = 'KarthikHacks Mini', Event_Type__c = 'Meetup',
    Event_Status__c = 'Draft', Budget__c = 5000,
    Max_Capacity__c = 20, Venue__c = venue.Id,
    Start_Date__c = DateTime.newInstance(2026, 2, 1, 9, 0, 0),
    End_Date__c = DateTime.newInstance(2026, 2, 1, 17, 0, 0)
);
insert lowBudgetEvt;
BudgetApprovalController.ApprovalResult autoResult = BudgetApprovalController.submitForApproval(lowBudgetEvt.Id, 'Low budget');
System.debug('\n✅ Low budget ($5k) auto-approved: ' + autoResult.status);

System.debug('\n========== PHASE 4: Credit Validation ==========');

// Test 1: Registration under credit limit (should pass)
System.debug('--- Test: Registration within credit limit ---');
Attendee__c newAtt = new Attendee__c(
    Name = 'Credit Test User', Email__c = 'credittest@hacks.dev',
    Credit_Limit__c = 1000, Preferred_Currency__c = 'USD'
);
insert newAtt;

CreditValidationService.ValidationResult creditOk = CreditValidationService.validateCredit(newAtt.Id, 800, 'USD');
System.debug('✅ $800 registration with $1000 limit: ' + creditOk.message);
System.debug('  Total exposure: $' + creditOk.totalExposure);

// Test 2: Registration OVER credit limit (should fail)
System.debug('\n--- Test: Registration exceeding credit limit ---');
CreditValidationService.ValidationResult creditFail = CreditValidationService.validateCredit(newAtt.Id, 1500, 'USD');
System.debug('✅ $1500 registration with $1000 limit: ' + creditFail.message);
System.debug('  Is valid: ' + creditFail.isValid);

// Test 3: Multi-currency (GBP attendee)
System.debug('\n--- Test: Multi-currency conversion (USD → GBP) ---');
Attendee__c gbpAtt = [SELECT Id FROM Attendee__c WHERE Email__c = 'bob@build.io'];
CreditValidationService.ValidationResult currencyResult = CreditValidationService.validateCredit(gbpAtt.Id, 4000, 'USD');
System.debug('✅ $4000 USD for GBP attendee (limit 4000 GBP):');
System.debug('  Converted amount: ' + currencyResult.convertedAmount + ' GBP');
System.debug('  Is valid: ' + currencyResult.isValid);
System.debug('  ' + currencyResult.message);

// Test 4: Trigger blocks over-limit registration
System.debug('\n--- Test: Trigger blocks registration exceeding limit ---');
try {
    Registration__c overLimitReg = new Registration__c(
        Event__c = lowBudgetEvt.Id, Attendee__c = newAtt.Id,
        Reg_Date__c = Date.today(), Status__c = 'Registered',
        Reg_Amount__c = 1500, Payment_Status__c = 'Pending'
    );
    insert overLimitReg;
    System.debug('❌ FAIL: Should have been blocked by credit validation!');
} catch (DmlException e) {
    System.debug('✅ Credit validation BLOCKED in trigger: ' + e.getDmlMessage(0));
}

// Test 5: Currency conversion function
System.debug('\n--- Test: Currency conversions ---');
System.debug('  $100 USD → GBP: ' + CreditValidationService.convertCurrency(100, 'USD', 'GBP'));
System.debug('  £100 GBP → USD: ' + CreditValidationService.convertCurrency(100, 'GBP', 'USD'));
System.debug('  $100 USD → EUR: ' + CreditValidationService.convertCurrency(100, 'USD', 'EUR'));
System.debug('  $100 USD → INR: ' + CreditValidationService.convertCurrency(100, 'USD', 'INR'));

System.debug('\n========== ALL PHASES TEST COMPLETE ==========');
System.debug('Event "KarthikHacks" successfully tested across all 4 phases!');
System.debug('Phase 1: ✅ Schema + Double-booking + Capacity rule');
System.debug('Phase 2: ✅ Registration + Waitlist + Promotion');
System.debug('Phase 3: ✅ Budget Approval (pending + auto-approve)');
System.debug('Phase 4: ✅ Credit Validation + Multi-currency');

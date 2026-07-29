// Cancel a confirmed registration to trigger PromoteWaitlistJob + email
// This should promote the #1 waitlisted person and email them

// Find the waitlisted person (your registration REG-00035 at position 6)
Registration__c waitlisted = [
    SELECT Id, Name, Attendee__r.Name, Attendee__r.Email__c, Waitlist_Position__c
    FROM Registration__c
    WHERE Event__r.Name = 'KarthikHacks' AND Status__c = 'Waitlisted'
    ORDER BY Waitlist_Position__c ASC LIMIT 1
];
System.debug('Top waitlisted: ' + waitlisted.Attendee__r.Name + ' (' + waitlisted.Attendee__r.Email__c + ') at position ' + waitlisted.Waitlist_Position__c);

// Cancel one confirmed registration
Registration__c toCancel = [
    SELECT Id, Name, Attendee__r.Name
    FROM Registration__c
    WHERE Event__r.Name = 'KarthikHacks' AND Status__c = 'Confirmed'
    LIMIT 1
];
System.debug('Cancelling: ' + toCancel.Name + ' (' + toCancel.Attendee__r.Name + ')');
toCancel.Status__c = 'Cancelled';
update toCancel;
System.debug('Cancelled. PromoteWaitlistJob should now run async and send email to: ' + waitlisted.Attendee__r.Email__c);

// Check email deliverability setting
System.debug('Org email deliverability check — if set to "System Email Only" or "No Access", emails wont send to external addresses.');

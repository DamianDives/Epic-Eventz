public with sharing class RegistrationService {

    public class RegistrationRequest {
        @InvocableVariable(required=true) public Id eventId;
        @InvocableVariable(required=true) public String attendeeName;
        @InvocableVariable(required=true) public String email;
        @InvocableVariable public String phone;
        @InvocableVariable public String company;
        @InvocableVariable public Decimal regAmount;
    }

    public class RegistrationResult {
        @InvocableVariable public Id registrationId;
        @InvocableVariable public String status; // 'Confirmed' or 'Waitlisted'
        @InvocableVariable public Integer waitlistPosition;
        @InvocableVariable public Boolean success;
        @InvocableVariable public String errorMessage;
    }

    @InvocableMethod(label='Register Attendee' description='Creates or finds attendee and registers them for an event')
    public static List<RegistrationResult> registerAttendees(List<RegistrationRequest> requests) {
        List<RegistrationResult> results = new List<RegistrationResult>();
        
        // Collect all emails for bulk query
        Set<String> emails = new Set<String>();
        Set<Id> eventIds = new Set<Id>();
        for (RegistrationRequest req : requests) {
            emails.add(req.email.toLowerCase());
            eventIds.add(req.eventId);
        }
        
        // Bulk query existing attendees by email
        Map<String, Attendee__c> existingAttendees = new Map<String, Attendee__c>();
        for (Attendee__c att : [SELECT Id, Email__c FROM Attendee__c WHERE Email__c IN :emails]) {
            existingAttendees.put(att.Email__c.toLowerCase(), att);
        }
        
        // Bulk query events for capacity info
        Map<Id, Event__c> events = new Map<Id, Event__c>([
            SELECT Id, Max_Capacity__c
            FROM Event__c WHERE Id IN :eventIds
        ]);
        
        // Count existing confirmed registrations per event
        Map<Id, Integer> confirmedCounts = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Event__c, COUNT(Id) cnt 
            FROM Registration__c 
            WHERE Event__c IN :eventIds AND Status__c = 'Confirmed'
            GROUP BY Event__c
        ]) {
            confirmedCounts.put((Id)ar.get('Event__c'), (Integer)ar.get('cnt'));
        }
        
        // Bulk query existing waitlist counts
        Map<Id, Integer> waitlistCounts = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Event__c, COUNT(Id) cnt 
            FROM Registration__c 
            WHERE Event__c IN :eventIds AND Status__c = 'Waitlisted'
            GROUP BY Event__c
        ]) {
            waitlistCounts.put((Id)ar.get('Event__c'), (Integer)ar.get('cnt'));
        }
        
        // Process each request
        List<Attendee__c> newAttendees = new List<Attendee__c>();
        List<Integer> newAttendeeIndices = new List<Integer>();
        
        for (Integer i = 0; i < requests.size(); i++) {
            RegistrationRequest req = requests[i];
            String emailKey = req.email.toLowerCase();
            
            if (!existingAttendees.containsKey(emailKey)) {
                Attendee__c newAtt = new Attendee__c(
                    Name = req.attendeeName,
                    Email__c = req.email,
                    Phone__c = req.phone,
                    Company__c = req.company
                );
                newAttendees.add(newAtt);
                newAttendeeIndices.add(i);
            }
        }
        
        // Insert new attendees
        if (!newAttendees.isEmpty()) {
            insert newAttendees;
            for (Integer i = 0; i < newAttendees.size(); i++) {
                Integer reqIndex = newAttendeeIndices[i];
                String emailKey = requests[reqIndex].email.toLowerCase();
                existingAttendees.put(emailKey, newAttendees[i]);
            }
        }
        
        // Create registrations
        List<Registration__c> regsToInsert = new List<Registration__c>();
        List<Integer> regIndices = new List<Integer>();
        
        // Track capacity increments within this batch
        Map<Id, Integer> batchConfirmedCount = new Map<Id, Integer>();
        Map<Id, Integer> batchWaitlistCount = new Map<Id, Integer>();
        
        for (Integer i = 0; i < requests.size(); i++) {
            RegistrationRequest req = requests[i];
            RegistrationResult result = new RegistrationResult();
            
            Event__c evt = events.get(req.eventId);
            if (evt == null) {
                result.success = false;
                result.errorMessage = 'Event not found';
                results.add(result);
                continue;
            }
            
            String emailKey = req.email.toLowerCase();
            Attendee__c attendee = existingAttendees.get(emailKey);
            
            // Calculate current capacity including batch additions
            Integer batchConfirmed = batchConfirmedCount.containsKey(req.eventId) ? batchConfirmedCount.get(req.eventId) : 0;
            Integer existingConfirmed = confirmedCounts.containsKey(req.eventId) ? confirmedCounts.get(req.eventId) : 0;
            Integer currentRegs = existingConfirmed + batchConfirmed;
            Decimal maxCap = evt.Max_Capacity__c != null ? evt.Max_Capacity__c : 0;
            
            Registration__c reg = new Registration__c(
                Event__c = req.eventId,
                Attendee__c = attendee.Id,
                Reg_Date__c = Date.today(),
                Reg_Amount__c = req.regAmount,
                Payment_Status__c = 'Pending'
            );
            
            if (currentRegs < maxCap) {
                reg.Status__c = 'Confirmed';
                result.status = 'Confirmed';
                batchConfirmedCount.put(req.eventId, batchConfirmed + 1);
            } else {
                reg.Status__c = 'Waitlisted';
                Integer existingWaitlist = waitlistCounts.containsKey(req.eventId) ? waitlistCounts.get(req.eventId) : 0;
                Integer batchWaitlist = batchWaitlistCount.containsKey(req.eventId) ? batchWaitlistCount.get(req.eventId) : 0;
                reg.Waitlist_Position__c = existingWaitlist + batchWaitlist + 1;
                result.status = 'Waitlisted';
                result.waitlistPosition = (Integer)reg.Waitlist_Position__c;
                batchWaitlistCount.put(req.eventId, batchWaitlist + 1);
            }
            
            regsToInsert.add(reg);
            regIndices.add(i);
            result.success = true;
            results.add(result);
        }
        
        // Bulk insert registrations
        if (!regsToInsert.isEmpty()) {
            List<Database.SaveResult> saveResults = Database.insert(regsToInsert, false);
            for (Integer i = 0; i < saveResults.size(); i++) {
                Integer resultIndex = regIndices[i];
                if (saveResults[i].isSuccess()) {
                    results[resultIndex].registrationId = saveResults[i].getId();
                } else {
                    results[resultIndex].success = false;
                    results[resultIndex].errorMessage = saveResults[i].getErrors()[0].getMessage();
                }
            }
        }
        
        return results;
    }
}

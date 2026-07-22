public with sharing class RegistrationTriggerHandler {

    public void handleBeforeInsert(List<Registration__c> newRegs) {
        // Set status based on capacity
        Set<Id> eventIds = new Set<Id>();
        for (Registration__c reg : newRegs) {
            if (reg.Event__c != null) {
                eventIds.add(reg.Event__c);
            }
        }
        
        if (eventIds.isEmpty()) return;
        
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
        
        // Get existing waitlist counts
        Map<Id, Integer> waitlistCounts = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Event__c, COUNT(Id) cnt
            FROM Registration__c
            WHERE Event__c IN :eventIds AND Status__c = 'Waitlisted'
            GROUP BY Event__c
        ]) {
            waitlistCounts.put((Id)ar.get('Event__c'), (Integer)ar.get('cnt'));
        }
        
        // Track capacity within batch
        Map<Id, Integer> batchConfirmed = new Map<Id, Integer>();
        Map<Id, Integer> batchWaitlisted = new Map<Id, Integer>();
        
        for (Registration__c reg : newRegs) {
            if (reg.Event__c == null) continue;
            // Only auto-set status if it's not already set by RegistrationService
            // RegistrationService pre-sets 'Confirmed' or 'Waitlisted'
            // Direct inserts come in as 'Registered' or null
            if (reg.Status__c != null && reg.Status__c != 'Registered') continue;
            
            Event__c evt = events.get(reg.Event__c);
            if (evt == null) continue;
            
            Integer existingConfirmed = confirmedCounts.containsKey(reg.Event__c) ? confirmedCounts.get(reg.Event__c) : 0;
            Integer confirmed = batchConfirmed.containsKey(reg.Event__c) ? batchConfirmed.get(reg.Event__c) : 0;
            Integer currentRegs = existingConfirmed + confirmed;
            Decimal maxCap = evt.Max_Capacity__c != null ? evt.Max_Capacity__c : 0;
            
            if (currentRegs < maxCap) {
                reg.Status__c = 'Confirmed';
                batchConfirmed.put(reg.Event__c, confirmed + 1);
            } else {
                reg.Status__c = 'Waitlisted';
                Integer existingWaitlist = waitlistCounts.containsKey(reg.Event__c) ? waitlistCounts.get(reg.Event__c) : 0;
                Integer batchWait = batchWaitlisted.containsKey(reg.Event__c) ? batchWaitlisted.get(reg.Event__c) : 0;
                reg.Waitlist_Position__c = existingWaitlist + batchWait + 1;
                batchWaitlisted.put(reg.Event__c, batchWait + 1);
            }
        }
    }

    public void handleAfterUpdate(List<Registration__c> newRegs, Map<Id, Registration__c> oldMap) {
        // When a registration changes from Confirmed to Cancelled, promote waitlist
        Set<Id> eventIdsToPromote = new Set<Id>();
        
        for (Registration__c reg : newRegs) {
            Registration__c oldReg = oldMap.get(reg.Id);
            if (oldReg.Status__c == 'Confirmed' && reg.Status__c == 'Cancelled') {
                eventIdsToPromote.add(reg.Event__c);
            }
        }
        
        if (!eventIdsToPromote.isEmpty()) {
            System.enqueueJob(new PromoteWaitlistJob(eventIdsToPromote));
        }
    }
}

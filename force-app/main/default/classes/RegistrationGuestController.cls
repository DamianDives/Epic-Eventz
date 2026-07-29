public without sharing class RegistrationGuestController {

    @AuraEnabled(cacheable=true)
    public static List<EventWrapper> getPublishedEvents() {
        List<Event__c> events = Database.query(
            'SELECT Id, Name, Event_Type__c, Event_Status__c, Start_Date__c, End_Date__c, ' +
            'Max_Capacity__c, Event_Price__c, Venue__r.Name, Venue__r.City__c, Venue__r.State__c ' +
            'FROM Event__c WHERE Event_Status__c = \'Published\' ORDER BY Start_Date__c ASC',
            AccessLevel.SYSTEM_MODE
        );

        Set<Id> eventIds = new Set<Id>();
        for (Event__c e : events) {
            eventIds.add(e.Id);
        }

        Map<Id, Integer> confirmedCounts = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Event__c, COUNT(Id) cnt FROM Registration__c
            WHERE Event__c IN :eventIds AND Status__c = 'Confirmed'
            GROUP BY Event__c
        ]) {
            confirmedCounts.put((Id)ar.get('Event__c'), (Integer)ar.get('cnt'));
        }

        List<EventWrapper> wrappers = new List<EventWrapper>();
        for (Event__c e : events) {
            EventWrapper w = new EventWrapper();
            w.Id = e.Id;
            w.Name = e.Name;
            w.eventType = e.Event_Type__c;
            w.startDate = e.Start_Date__c;
            w.endDate = e.End_Date__c;
            w.maxCapacity = e.Max_Capacity__c;
            w.eventPrice = e.Event_Price__c;
            w.venueName = e.Venue__r != null
                ? e.Venue__r.City__c + ', ' + e.Venue__r.State__c : 'TBD';
            Integer confirmed = confirmedCounts.containsKey(e.Id)
                ? confirmedCounts.get(e.Id) : 0;
            w.seatsRemaining = e.Max_Capacity__c != null
                ? Integer.valueOf(e.Max_Capacity__c) - confirmed : null;
            wrappers.add(w);
        }
        return wrappers;
    }

    @AuraEnabled
    public static RegistrationController.RegistrationResult registerForEvent(
        String eventId, String attendeeName, String email,
        String phone, String company, Decimal regAmount
    ) {
        return RegistrationController.registerForEvent(
            eventId, attendeeName, email, phone, company, regAmount
        );
    }

    public class EventWrapper {
        @AuraEnabled public Id Id;
        @AuraEnabled public String Name;
        @AuraEnabled public String eventType;
        @AuraEnabled public DateTime startDate;
        @AuraEnabled public DateTime endDate;
        @AuraEnabled public Decimal maxCapacity;
        @AuraEnabled public Decimal eventPrice;
        @AuraEnabled public String venueName;
        @AuraEnabled public Integer seatsRemaining;
    }
}

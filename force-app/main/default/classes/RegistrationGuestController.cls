public without sharing class RegistrationGuestController {
    
    @AuraEnabled(cacheable=true)
    public static List<Event__c> getPublishedEvents() {
        return [
            SELECT Id, Name, Event_Type__c, Event_Status__c, Start_Date__c, End_Date__c,
                   Max_Capacity__c, Venue__r.Name, Venue__r.City__c, Venue__r.State__c
            FROM Event__c
            WHERE Event_Status__c = 'Published'
            ORDER BY Start_Date__c ASC
        ];
    }
    
    @AuraEnabled
    public static RegistrationController.RegistrationResult registerForEvent(
        String eventId, String attendeeName, String email, 
        String phone, String company, Decimal regAmount
    ) {
        return RegistrationController.registerForEvent(eventId, attendeeName, email, phone, company, regAmount);
    }
}

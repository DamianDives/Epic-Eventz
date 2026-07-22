public without sharing class PromoteWaitlistJob implements Queueable {
    
    private Set<Id> eventIds;
    
    public PromoteWaitlistJob(Set<Id> eventIds) {
        this.eventIds = eventIds;
    }
    
    public void execute(QueueableContext context) {
        // For each event, find the top waitlisted registration and promote it
        List<Registration__c> toPromote = new List<Registration__c>();
        
        for (Id eventId : eventIds) {
            List<Registration__c> waitlisted = [
                SELECT Id, Event__c, Attendee__c, Waitlist_Position__c
                FROM Registration__c
                WHERE Event__c = :eventId 
                  AND Status__c = 'Waitlisted'
                ORDER BY Waitlist_Position__c ASC
                LIMIT 1
            ];
            
            if (!waitlisted.isEmpty()) {
                Registration__c reg = waitlisted[0];
                reg.Status__c = 'Confirmed';
                reg.Waitlist_Position__c = null;
                toPromote.add(reg);
            }
        }
        
        if (!toPromote.isEmpty()) {
            Database.update(toPromote, AccessLevel.SYSTEM_MODE);
            
            // Send confirmation emails
            RegistrationEmailService.sendPromotionEmails(toPromote);
        }
    }
}

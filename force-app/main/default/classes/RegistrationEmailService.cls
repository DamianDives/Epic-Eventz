public with sharing class RegistrationEmailService {
    
    public static void sendPromotionEmails(List<Registration__c> promotedRegs) {
        if (promotedRegs.isEmpty()) return;
        
        // Query full details for email
        Set<Id> regIds = new Set<Id>();
        for (Registration__c reg : promotedRegs) {
            regIds.add(reg.Id);
        }
        
        List<Registration__c> fullRegs = [
            SELECT Id, Event__r.Name, Event__r.Start_Date__c, Event__r.End_Date__c,
                   Attendee__r.Name, Attendee__r.Email__c
            FROM Registration__c
            WHERE Id IN :regIds
        ];
        
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        
        for (Registration__c reg : fullRegs) {
            if (reg.Attendee__r.Email__c == null) continue;
            
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{reg.Attendee__r.Email__c});
            mail.setSubject('You\'re In! Registration Confirmed - ' + reg.Event__r.Name);
            mail.setPlainTextBody(
                'Dear ' + reg.Attendee__r.Name + ',\n\n' +
                'Great news! A spot has opened up and your registration for ' + reg.Event__r.Name + ' has been confirmed.\n\n' +
                'Event Details:\n' +
                'Start: ' + String.valueOf(reg.Event__r.Start_Date__c) + '\n' +
                'End: ' + String.valueOf(reg.Event__r.End_Date__c) + '\n\n' +
                'We look forward to seeing you there!\n\n' +
                'Best regards,\nEpicEventz Team'
            );
            emails.add(mail);
        }
        
        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails, false); // false = don't throw on failure
        }
    }
}

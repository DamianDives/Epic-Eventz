public without sharing class RegistrationEmailService {
    
    /**
     * Send confirmation email when registration is successful (Confirmed)
     */
    public static void sendRegistrationConfirmedEmail(List<Registration__c> regs) {
        sendEmails(regs, 'confirmed');
    }
    
    /**
     * Send waitlisted email when event is full
     */
    public static void sendWaitlistedEmail(List<Registration__c> regs) {
        sendEmails(regs, 'waitlisted');
    }
    
    /**
     * Send cancellation email when user cancels
     */
    public static void sendCancellationEmail(List<Registration__c> regs) {
        sendEmails(regs, 'cancelled');
    }
    
    /**
     * Send promotion email when waitlisted person gets a spot
     */
    public static void sendPromotionEmails(List<Registration__c> regs) {
        sendEmails(regs, 'promoted');
    }
    
    private static void sendEmails(List<Registration__c> regs, String emailType) {
        if (regs == null || regs.isEmpty()) return;
        
        Set<Id> regIds = new Set<Id>();
        for (Registration__c r : regs) { regIds.add(r.Id); }
        
        List<Registration__c> fullRegs = [
            SELECT Id, Name, Reg_Amount__c, Waitlist_Position__c,
                   Event__r.Name, Event__r.Start_Date__c, Event__r.End_Date__c,
                   Event__r.Venue__r.City__c, Event__r.Venue__r.State__c,
                   Attendee__r.Name, Attendee__r.Email__c
            FROM Registration__c WHERE Id IN :regIds
        ];
        
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        
        for (Registration__c reg : fullRegs) {
            if (reg.Attendee__r.Email__c == null) continue;
            
            String subject;
            String body;
            String venue = (reg.Event__r.Venue__r != null) 
                ? reg.Event__r.Venue__r.City__c + ', ' + reg.Event__r.Venue__r.State__c 
                : 'TBD';
            String eventDates = 'Start: ' + String.valueOf(reg.Event__r.Start_Date__c) + 
                '\nEnd: ' + String.valueOf(reg.Event__r.End_Date__c);
            
            if (emailType == 'confirmed') {
                subject = 'Registration Confirmed - ' + reg.Event__r.Name;
                body = 'Dear ' + reg.Attendee__r.Name + ',\n\n' +
                    'Your registration for ' + reg.Event__r.Name + ' is confirmed!\n\n' +
                    'Registration #: ' + reg.Name + '\n' +
                    'Amount: $' + reg.Reg_Amount__c + '\n' +
                    'Venue: ' + venue + '\n' +
                    eventDates + '\n\n' +
                    'We look forward to seeing you there!\n\n' +
                    'Best regards,\nEpicEventz Team';
                    
            } else if (emailType == 'waitlisted') {
                subject = 'You\'re on the Waitlist - ' + reg.Event__r.Name;
                body = 'Dear ' + reg.Attendee__r.Name + ',\n\n' +
                    'Thank you for registering for ' + reg.Event__r.Name + '.\n\n' +
                    'The event is currently full. You have been placed on the waitlist.\n\n' +
                    'Registration #: ' + reg.Name + '\n' +
                    'Waitlist Position: #' + Integer.valueOf(reg.Waitlist_Position__c) + '\n\n' +
                    'We will notify you immediately if a spot opens up.\n\n' +
                    'Best regards,\nEpicEventz Team';
                    
            } else if (emailType == 'cancelled') {
                subject = 'Registration Cancelled - ' + reg.Event__r.Name;
                body = 'Dear ' + reg.Attendee__r.Name + ',\n\n' +
                    'Your registration for ' + reg.Event__r.Name + ' has been cancelled.\n\n' +
                    'Registration #: ' + reg.Name + '\n\n' +
                    'If this was a mistake, you can register again on our site.\n\n' +
                    'Best regards,\nEpicEventz Team';
                    
            } else if (emailType == 'promoted') {
                subject = 'You\'re In! Spot Available - ' + reg.Event__r.Name;
                body = 'Dear ' + reg.Attendee__r.Name + ',\n\n' +
                    'Great news! A spot has opened up and your registration for ' + 
                    reg.Event__r.Name + ' has been confirmed!\n\n' +
                    'Registration #: ' + reg.Name + '\n' +
                    'Venue: ' + venue + '\n' +
                    eventDates + '\n\n' +
                    'We look forward to seeing you there!\n\n' +
                    'Best regards,\nEpicEventz Team';
            }
            
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{reg.Attendee__r.Email__c});
            mail.setSubject(subject);
            mail.setPlainTextBody(body);
            mail.setSenderDisplayName('EpicEventz');
            emails.add(mail);
        }
        
        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails, false);
        }
    }
}

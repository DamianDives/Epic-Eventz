public with sharing class RegistrationController {
    
    @AuraEnabled(cacheable=true)
    public static List<Event__c> getPublishedEvents() {
        return [
            SELECT Id, Name, Event_Type__c, Event_Status__c, Start_Date__c, End_Date__c,
                   Max_Capacity__c,
                   Venue__r.Name, Venue__r.City__c, Venue__r.State__c
            FROM Event__c
            WHERE Event_Status__c = 'Published'
            ORDER BY Start_Date__c ASC
        ];
    }
    
    @AuraEnabled
    public static RegistrationResult registerForEvent(String eventId, String attendeeName, String email, String phone, String company, Decimal regAmount) {
        RegistrationResult result = new RegistrationResult();
        
        try {
            // Find or create attendee
            List<Attendee__c> existingAttendees = [SELECT Id FROM Attendee__c WHERE Email__c = :email LIMIT 1];
            Attendee__c attendee;
            
            if (!existingAttendees.isEmpty()) {
                attendee = existingAttendees[0];
            } else {
                attendee = new Attendee__c(
                    Name = attendeeName,
                    Email__c = email,
                    Phone__c = phone,
                    Company__c = company
                );
                insert attendee;
            }
            
            // Check capacity
            Event__c evt = [SELECT Id, Max_Capacity__c FROM Event__c WHERE Id = :eventId];
            Integer confirmedCount = [SELECT COUNT() FROM Registration__c WHERE Event__c = :eventId AND Status__c = 'Confirmed'];
            Integer waitlistCount = [SELECT COUNT() FROM Registration__c WHERE Event__c = :eventId AND Status__c = 'Waitlisted'];
            
            Registration__c reg = new Registration__c(
                Event__c = eventId,
                Attendee__c = attendee.Id,
                Reg_Date__c = Date.today(),
                Reg_Amount__c = regAmount,
                Payment_Status__c = 'Pending'
            );
            
            Decimal maxCap = evt.Max_Capacity__c != null ? evt.Max_Capacity__c : 0;
            
            // Credit validation
            if (regAmount != null && regAmount > 0) {
                CreditValidationService.ValidationResult creditResult = 
                    CreditValidationService.validateCredit(attendee.Id, regAmount, 'USD');
                if (!creditResult.isValid) {
                    result.success = false;
                    result.errorMessage = creditResult.message;
                    return result;
                }
                reg.Converted_Amount__c = creditResult.convertedAmount;
                reg.Credit_Validation_Status__c = 'Passed';
            }
            
            if (confirmedCount < maxCap) {
                reg.Status__c = 'Confirmed';
                result.status = 'Confirmed';
            } else {
                reg.Status__c = 'Waitlisted';
                reg.Waitlist_Position__c = waitlistCount + 1;
                result.status = 'Waitlisted';
                result.waitlistPosition = waitlistCount + 1;
            }
            
            insert reg;
            result.registrationId = reg.Id;
            result.success = true;
            result.regNumber = [SELECT Name FROM Registration__c WHERE Id = :reg.Id].Name;
            
        } catch (Exception e) {
            result.success = false;
            result.errorMessage = e.getMessage();
        }
        
        return result;
    }
    
    public class RegistrationResult {
        @AuraEnabled public String registrationId;
        @AuraEnabled public String regNumber;
        @AuraEnabled public String status;
        @AuraEnabled public Integer waitlistPosition;
        @AuraEnabled public Boolean success;
        @AuraEnabled public String errorMessage;
    }
}

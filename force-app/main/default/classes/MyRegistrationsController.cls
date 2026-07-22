public without sharing class MyRegistrationsController {
    
    @AuraEnabled(cacheable=true)
    public static List<RegistrationWrapper> getMyRegistrations(String email) {
        List<RegistrationWrapper> wrappers = new List<RegistrationWrapper>();
        
        if (String.isBlank(email)) return wrappers;
        
        List<Registration__c> regs = [
            SELECT Id, Name, Status__c, Reg_Date__c, Reg_Amount__c,
                   Waitlist_Position__c, Payment_Status__c,
                   Event__r.Name, Event__r.Event_Type__c,
                   Event__r.Start_Date__c, Event__r.End_Date__c,
                   Event__r.Venue__r.City__c, Event__r.Venue__r.State__c
            FROM Registration__c
            WHERE Attendee__r.Email__c = :email
            AND Status__c != 'Cancelled'
            ORDER BY Event__r.Start_Date__c DESC
        ];
        
        for (Registration__c reg : regs) {
            RegistrationWrapper w = new RegistrationWrapper();
            w.regId = reg.Id;
            w.regNumber = reg.Name;
            w.status = reg.Status__c;
            w.regDate = reg.Reg_Date__c;
            w.amount = reg.Reg_Amount__c;
            w.waitlistPosition = Integer.valueOf(reg.Waitlist_Position__c);
            w.eventName = reg.Event__r.Name;
            w.eventType = reg.Event__r.Event_Type__c;
            w.startDate = reg.Event__r.Start_Date__c;
            w.endDate = reg.Event__r.End_Date__c;
            w.venue = reg.Event__r.Venue__r != null
                ? reg.Event__r.Venue__r.City__c + ', ' + reg.Event__r.Venue__r.State__c
                : 'TBD';
            wrappers.add(w);
        }
        
        return wrappers;
    }
    
    @AuraEnabled
    public static CancelResult cancelRegistration(String regId) {
        CancelResult result = new CancelResult();
        
        try {
            Registration__c reg = [
                SELECT Id, Status__c, Event__c, Attendee__r.Email__c
                FROM Registration__c WHERE Id = :regId
            ];
            
            if (reg.Status__c == 'Cancelled') {
                result.success = false;
                result.message = 'This registration is already cancelled.';
                return result;
            }
            
            // Set to Cancelled — this triggers the after update handler
            // which enqueues PromoteWaitlistJob if it was Confirmed
            reg.Status__c = 'Cancelled';
            update reg;
            
            result.success = true;
            result.message = 'Registration cancelled successfully.';
            
            if (reg.Status__c == 'Confirmed') {
                result.message += ' The next person on the waitlist will be notified.';
            }
            
        } catch (Exception e) {
            result.success = false;
            result.message = 'Error: ' + e.getMessage();
        }
        
        return result;
    }
    
    @AuraEnabled(cacheable=true)
    public static String getCurrentUserEmail() {
        return [SELECT Email FROM User WHERE Id = :UserInfo.getUserId()].Email;
    }
    
    public class RegistrationWrapper {
        @AuraEnabled public String regId;
        @AuraEnabled public String regNumber;
        @AuraEnabled public String status;
        @AuraEnabled public Date regDate;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public Integer waitlistPosition;
        @AuraEnabled public String eventName;
        @AuraEnabled public String eventType;
        @AuraEnabled public DateTime startDate;
        @AuraEnabled public DateTime endDate;
        @AuraEnabled public String venue;
    }
    
    public class CancelResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
    }
}

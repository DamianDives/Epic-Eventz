public with sharing class BudgetApprovalController {
    
    private static final Decimal APPROVAL_THRESHOLD = 10000;
    
    private static Boolean hasFinancePermission() {
        List<PermissionSetAssignment> assignments = [
            SELECT Id FROM PermissionSetAssignment 
            WHERE AssigneeId = :UserInfo.getUserId() 
            AND PermissionSet.Name = 'EpicEventz_Finance'
        ];
        // Also allow System Admins
        Profile p = [SELECT Name FROM Profile WHERE Id = :UserInfo.getProfileId()];
        return !assignments.isEmpty() || p.Name == 'System Administrator';
    }
    
    @AuraEnabled
    public static ApprovalResult submitForApproval(Id eventId, String comments) {
        ApprovalResult result = new ApprovalResult();
        try {
            Event__c evt = [SELECT Id, Name, Budget__c, Approval_Status__c, Event_Status__c FROM Event__c WHERE Id = :eventId];
            
            if (evt.Budget__c == null || evt.Budget__c <= APPROVAL_THRESHOLD) {
                evt.Approval_Status__c = 'Approved';
                evt.Event_Status__c = 'Published';
                update evt;
                result.success = true;
                result.status = 'Auto-Approved';
                result.message = 'Budget is within threshold ($' + APPROVAL_THRESHOLD + '). Auto-approved.';
                return result;
            }
            
            evt.Approval_Status__c = 'Pending';
            update evt;
            result.success = true;
            result.status = 'Pending';
            result.message = 'Submitted for approval. Budget ($' + evt.Budget__c + ') exceeds threshold.';
        } catch (Exception e) {
            result.success = false;
            result.message = e.getMessage();
        }
        return result;
    }
    
    @AuraEnabled
    public static ApprovalResult approveEvent(Id eventId, String comments) {
        ApprovalResult result = new ApprovalResult();
        try {
            if (!hasFinancePermission()) {
                result.success = false;
                result.message = 'Only Finance Managers can approve budgets. Please contact your administrator.';
                return result;
            }
            
            Event__c evt = [SELECT Id, Budget__c, Approval_Status__c FROM Event__c WHERE Id = :eventId];
            evt.Approval_Status__c = 'Approved';
            evt.Approved_Budget__c = evt.Budget__c;
            evt.Event_Status__c = 'Published';
            update evt;
            result.success = true;
            result.status = 'Approved';
            result.message = 'Event budget approved and status set to Published.';
        } catch (Exception e) {
            result.success = false;
            result.message = e.getMessage();
        }
        return result;
    }
    
    @AuraEnabled
    public static ApprovalResult rejectEvent(Id eventId, String comments) {
        ApprovalResult result = new ApprovalResult();
        try {
            if (!hasFinancePermission()) {
                result.success = false;
                result.message = 'Only Finance Managers can reject budgets. Please contact your administrator.';
                return result;
            }
            
            Event__c evt = [SELECT Id FROM Event__c WHERE Id = :eventId];
            evt.Approval_Status__c = 'Rejected';
            evt.Event_Status__c = 'Draft';
            update evt;
            result.success = true;
            result.status = 'Rejected';
            result.message = 'Event budget rejected. Status reverted to Draft.';
        } catch (Exception e) {
            result.success = false;
            result.message = e.getMessage();
        }
        return result;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Event__c> getEventsForApproval() {
        return [
            SELECT Id, Name, Event_Type__c, Budget__c, Approval_Status__c, 
                   Start_Date__c, End_Date__c, Event_Status__c,
                   Venue__r.Name, Venue__r.City__c
            FROM Event__c
            WHERE Approval_Status__c = 'Pending'
            ORDER BY Budget__c DESC
        ];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Event__c> getAllEventsForSubmission() {
        return [
            SELECT Id, Name, Event_Type__c, Budget__c, Approval_Status__c,
                   Start_Date__c, Event_Status__c
            FROM Event__c
            WHERE Event_Status__c = 'Draft'
            AND (Approval_Status__c = null OR Approval_Status__c = 'Rejected')
            ORDER BY Start_Date__c ASC
        ];
    }
    
    @AuraEnabled(cacheable=true)
    public static Boolean checkFinanceAccess() {
        return hasFinancePermission();
    }
    
    public class ApprovalResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String status;
        @AuraEnabled public String message;
    }
}

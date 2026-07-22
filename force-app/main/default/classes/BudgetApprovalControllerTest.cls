@isTest
private class BudgetApprovalControllerTest {
    
    @TestSetup
    static void setup() {
        Venue__c venue = new Venue__c(
            Capacity__c = 500, Country__c = 'US', State__c = 'CA',
            City__c = 'SF', Venue_Type__c = 'Indoor', Address__c = '123 Test', Active__c = true
        );
        insert venue;
        
        Event__c highBudget = new Event__c(
            Name = 'High Budget Event', Event_Type__c = 'Conference',
            Event_Status__c = 'Draft', Budget__c = 50000, Max_Capacity__c = 200,
            Start_Date__c = DateTime.newInstance(2025, 12, 1, 9, 0, 0),
            End_Date__c = DateTime.newInstance(2025, 12, 3, 18, 0, 0),
            Venue__c = venue.Id
        );
        insert highBudget;
        
        Event__c lowBudget = new Event__c(
            Name = 'Low Budget Event', Event_Type__c = 'Meetup',
            Event_Status__c = 'Draft', Budget__c = 5000, Max_Capacity__c = 50,
            Start_Date__c = DateTime.newInstance(2025, 11, 1, 9, 0, 0),
            End_Date__c = DateTime.newInstance(2025, 11, 1, 17, 0, 0),
            Venue__c = venue.Id
        );
        insert lowBudget;
    }
    
    @isTest
    static void testSubmit_LowBudget_AutoApproves() {
        Event__c evt = [SELECT Id FROM Event__c WHERE Name = 'Low Budget Event'];
        
        Test.startTest();
        BudgetApprovalController.ApprovalResult result = BudgetApprovalController.submitForApproval(evt.Id, 'Test');
        Test.stopTest();
        
        System.assertEquals(true, result.success);
        System.assertEquals('Auto-Approved', result.status);
        
        Event__c updated = [SELECT Approval_Status__c, Event_Status__c FROM Event__c WHERE Id = :evt.Id];
        System.assertEquals('Approved', updated.Approval_Status__c);
        System.assertEquals('Published', updated.Event_Status__c);
    }
    
    @isTest
    static void testSubmit_HighBudget_SetsPending() {
        Event__c evt = [SELECT Id FROM Event__c WHERE Name = 'High Budget Event'];
        
        Test.startTest();
        BudgetApprovalController.ApprovalResult result = BudgetApprovalController.submitForApproval(evt.Id, 'Please approve');
        Test.stopTest();
        
        System.assertEquals(true, result.success);
        System.assertEquals('Pending', result.status);
        
        Event__c updated = [SELECT Approval_Status__c FROM Event__c WHERE Id = :evt.Id];
        System.assertEquals('Pending', updated.Approval_Status__c);
    }
    
    @isTest
    static void testApproveEvent() {
        Event__c evt = [SELECT Id FROM Event__c WHERE Name = 'High Budget Event'];
        evt.Approval_Status__c = 'Pending';
        update evt;
        
        Test.startTest();
        BudgetApprovalController.ApprovalResult result = BudgetApprovalController.approveEvent(evt.Id, 'Approved');
        Test.stopTest();
        
        System.assertEquals(true, result.success);
        System.assertEquals('Approved', result.status);
        
        Event__c updated = [SELECT Approval_Status__c, Approved_Budget__c, Event_Status__c FROM Event__c WHERE Id = :evt.Id];
        System.assertEquals('Approved', updated.Approval_Status__c);
        System.assertEquals(50000, updated.Approved_Budget__c);
        System.assertEquals('Published', updated.Event_Status__c);
    }
    
    @isTest
    static void testRejectEvent() {
        Event__c evt = [SELECT Id FROM Event__c WHERE Name = 'High Budget Event'];
        evt.Approval_Status__c = 'Pending';
        update evt;
        
        Test.startTest();
        BudgetApprovalController.ApprovalResult result = BudgetApprovalController.rejectEvent(evt.Id, 'Too expensive');
        Test.stopTest();
        
        System.assertEquals(true, result.success);
        System.assertEquals('Rejected', result.status);
        
        Event__c updated = [SELECT Approval_Status__c, Event_Status__c FROM Event__c WHERE Id = :evt.Id];
        System.assertEquals('Rejected', updated.Approval_Status__c);
        System.assertEquals('Draft', updated.Event_Status__c);
    }
    
    @isTest
    static void testGetEventsForApproval() {
        Event__c evt = [SELECT Id FROM Event__c WHERE Name = 'High Budget Event'];
        evt.Approval_Status__c = 'Pending';
        update evt;
        
        Test.startTest();
        List<Event__c> pending = BudgetApprovalController.getEventsForApproval();
        Test.stopTest();
        
        System.assertEquals(1, pending.size());
        System.assertEquals('High Budget Event', pending[0].Name);
    }
    
    @isTest
    static void testGetAllEventsForSubmission() {
        Test.startTest();
        List<Event__c> drafts = BudgetApprovalController.getAllEventsForSubmission();
        Test.stopTest();
        
        System.assert(drafts.size() >= 1, 'Should have at least one draft event');
    }
}

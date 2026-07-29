// Simulate what RegistrationController.registerForEvent does
try {
    // Use a published event
    Event__c evt = [SELECT Id, Name, Max_Capacity__c FROM Event__c WHERE Event_Status__c = 'Published' LIMIT 1];
    System.debug('Event: ' + evt.Name + ' (Id: ' + evt.Id + ')');
    
    RegistrationController.RegistrationResult result = RegistrationController.registerForEvent(
        evt.Id, 'Debug User', 'debugreg@test.com', '555-1234', 'TestCo', 100.00
    );
    
    System.debug('SUCCESS: ' + result.success);
    System.debug('STATUS: ' + result.status);
    System.debug('REG#: ' + result.regNumber);
    System.debug('ERROR: ' + result.errorMessage);
} catch (Exception e) {
    System.debug('EXCEPTION TYPE: ' + e.getTypeName());
    System.debug('EXCEPTION MSG: ' + e.getMessage());
    System.debug('STACK: ' + e.getStackTraceString());
}

trigger RegistrationTrigger on Registration__c (before insert, after update) {
    RegistrationTriggerHandler handler = new RegistrationTriggerHandler();
    
    if (Trigger.isBefore && Trigger.isInsert) {
        handler.handleBeforeInsert(Trigger.new);
    }
    if (Trigger.isAfter && Trigger.isUpdate) {
        handler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}

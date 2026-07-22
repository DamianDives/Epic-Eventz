trigger EventTrigger on Event__c (before insert, before update) {
    EventTriggerHandler handler = new EventTriggerHandler();
    
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            handler.handleBeforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            handler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}

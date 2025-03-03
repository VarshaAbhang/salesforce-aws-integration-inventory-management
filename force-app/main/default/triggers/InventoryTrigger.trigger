trigger InventoryTrigger on Inventory__c (before insert, before update, after insert, after update, before delete) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            for (Inventory__c inv : Trigger.new) {
                inv.Last_Updated__c = System.now();
            }
        }

        if (Trigger.isDelete) {
            InventoryTriggerHandler.handleBeforeDelete(Trigger.old);
        }
    }

    if (Trigger.isAfter) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            InventoryTriggerHandler.handleAfterInsertOrUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}
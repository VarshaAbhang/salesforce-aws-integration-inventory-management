public class InventoryTriggerHandler { 
    private static Set<Id> processedInventories = new Set<Id>(); // Prevent recursion

    public static void handleAfterInsertOrUpdate(List<Inventory__c> newInventories, Map<Id, Inventory__c> oldInventoriesMap) {
        Set<Id> inventoryIdsToSync = new Set<Id>();
        List<Inventory_Updated__e> eventList = new List<Inventory_Updated__e>();
        List<Inventory__c> inventoriesToUpdate = new List<Inventory__c>();
        Set<Id> productIdsToUpdate = new Set<Id>();

        for (Inventory__c inv : newInventories) {
            if (processedInventories.contains(inv.Id)) continue;
            processedInventories.add(inv.Id); 

            if (inv.SyncedWithDynamo__c == true) {
                inventoryIdsToSync.add(inv.Id);
            }
            
            Inventory__c oldInv = oldInventoriesMap != null ? oldInventoriesMap.get(inv.Id) : null;
            Boolean quantityChanged = (oldInv == null || oldInv.Quantity__c != inv.Quantity__c);
            Boolean statusChanged = (oldInv == null || oldInv.Status__c != inv.Status__c);

            String newStatus = inv.Status__c;

            // ✅ Update Status Based on Quantity Before Event Creation
            if (inv.Quantity__c == 0 && inv.Status__c != 'Out of Stock') {
                newStatus = 'Out of Stock';
                inventoriesToUpdate.add(new Inventory__c(Id = inv.Id, Status__c = newStatus));
            } else if (inv.Quantity__c > 0 && inv.Quantity__c < 10 && inv.Status__c != 'Low Stock') {
                newStatus = 'Low Stock';
                inventoriesToUpdate.add(new Inventory__c(Id = inv.Id, Status__c = newStatus));
            }

            // ✅ Create Platform Event
            if (quantityChanged || statusChanged) {
                Inventory_Updated__e eventMsg = new Inventory_Updated__e();
                eventMsg.InventoryId__c = inv.Id;
                eventMsg.Quantity__c = inv.Quantity__c;
                eventMsg.Status__c = newStatus;

                eventMsg.AlertType__c = (inv.Quantity__c == 0) ? 'Out Of Stock' : 
                                        (inv.Quantity__c > 0 && inv.Quantity__c < 10) ? 'Low Stock' : '';

                eventList.add(eventMsg);
            }

            // ✅ Add product to update stock quantity if necessary
            if (inv.Product__c != null) {
                productIdsToUpdate.add(inv.Product__c);
            }
        }

        // ✅ Bulk Update Inventory Records First
        if (!inventoriesToUpdate.isEmpty()) {
            update inventoriesToUpdate;
        }

        // ✅ Publish Platform Events
        if (!eventList.isEmpty()) {
            EventBus.publish(eventList);
        }

        // ✅ Sync Inventory with AWS (Separate Insert & Update)
        if (!inventoryIdsToSync.isEmpty()) {
            InventoryCallout.insertToDynamoDB(new List<Id>(inventoryIdsToSync));
            InventoryCallout.updateToDynamoDB(new List<Id>(inventoryIdsToSync));
        }

        // ✅ Bulk Update Product Stock Quantity
        if (!productIdsToUpdate.isEmpty()) {
            updateProductStockQuantities(productIdsToUpdate);
        }

        // ✅ Clear processed records for next execution
        processedInventories.clear();
    }

    public static void handleBeforeDelete(List<Inventory__c> oldInventories) {
        if (oldInventories == null || oldInventories.isEmpty()) return;

        Set<Id> inventoryIdsToDelete = new Set<Id>();
        for (Inventory__c inv : oldInventories) {
            inventoryIdsToDelete.add(inv.Id);
        }

        if (!inventoryIdsToDelete.isEmpty()) {
            InventoryCallout.deleteToDynamoDB(new List<Id>(inventoryIdsToDelete));
        }
    }

    // ✅ Helper method to update product stock quantities
    private static void updateProductStockQuantities(Set<Id> productIds) {
        Map<Id, Product__c> productsToUpdate = new Map<Id, Product__c>([
            SELECT Id, Stock_Quantity__c FROM Product__c WHERE Id IN :productIds
        ]);
        List<Product__c> productsToUpdateList = new List<Product__c>();

        for (Product__c prod : productsToUpdate.values()) {
            prod.Stock_Quantity__c = 0; // Reset quantity before recalculating
            for (Inventory__c inv : [SELECT Quantity__c FROM Inventory__c WHERE Product__c = :prod.Id]) {
                prod.Stock_Quantity__c += inv.Quantity__c;
            }
            productsToUpdateList.add(prod);
        }

        if (!productsToUpdateList.isEmpty()) {
            update productsToUpdateList;
        }
    }
}
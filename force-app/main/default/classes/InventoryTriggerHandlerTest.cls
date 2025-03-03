/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an org are executed whenever Apex code is deployed
 * to a production org to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production org. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the org size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@isTest
private class InventoryTriggerHandlerTest {
    
    @testSetup
    static void setupTestData() {
        // Create a Product record
        Product__c product = new Product__c(
            Name = 'Test Product',
			Category__c='Electronics', 
            SKU__c='SKU159',
            Stock_Quantity__c = 50
        );
        insert product;

        // Create Inventory records
        List<Inventory__c> inventoryList = new List<Inventory__c>{
            new Inventory__c(
                Name = 'Test Inventory 1',
                Quantity__c = 20,
                Status__c = 'Available',
                Product__c = product.Id,
                SyncedWithDynamo__c = true
            ),
            new Inventory__c(
                Name = 'Test Inventory 2',
                Quantity__c = 5,
                Status__c = 'Low Stock',
                Product__c = product.Id,
                SyncedWithDynamo__c = false
            )
        };
        insert inventoryList;
    }
    
    @isTest
    static void testAfterInsert() {
        Test.startTest();
        
        // Insert a new Inventory record
        Inventory__c newInventory = new Inventory__c(
            Name = 'New Inventory',
            Quantity__c = 0, // Should trigger status change to "Out of Stock"
            Status__c = 'Available',
            Product__c = [SELECT Id FROM Product__c LIMIT 1].Id,
            SyncedWithDynamo__c = true
        );
        insert newInventory;

        // Verify status update
        Inventory__c insertedInv = [SELECT Id, Status__c FROM Inventory__c WHERE Id = :newInventory.Id];
        System.assertEquals('Out Of Stock', insertedInv.Status__c);
        
        Test.stopTest();
    }

    @isTest
    static void testAfterUpdate() {
        Inventory__c invToUpdate = [SELECT Id, Quantity__c FROM Inventory__c LIMIT 1];
        invToUpdate.Quantity__c = 8; // Should trigger "Low Stock" status update
        update invToUpdate;

        Inventory__c updatedInv = [SELECT Id, Status__c FROM Inventory__c WHERE Id = :invToUpdate.Id];
        System.assertEquals('Low Stock', updatedInv.Status__c);
    }

    @isTest
    static void testAfterDelete() {
        List<Inventory__c> inventories = [SELECT Id FROM Inventory__c LIMIT 1];
        Test.startTest();
        delete inventories;
        Test.stopTest();

        List<Inventory__c> deletedInventories = [SELECT Id FROM Inventory__c WHERE Id IN :inventories];
        System.assertEquals(0, deletedInventories.size());
    }

    @isTest
    static void testProductStockUpdate() {
        // Fetch product before update
        Product__c productBefore = [SELECT Id, Stock_Quantity__c FROM Product__c LIMIT 1];

        // Reduce inventory quantity
        Inventory__c invToUpdate = [SELECT Id, Quantity__c FROM Inventory__c WHERE Product__c = :productBefore.Id LIMIT 1];
        invToUpdate.Quantity__c = 2;
        update invToUpdate;

        // Fetch product after update
        Product__c productAfter = [SELECT Id, Stock_Quantity__c FROM Product__c WHERE Id = :productBefore.Id];
        System.assertNotEquals(productBefore.Stock_Quantity__c, productAfter.Stock_Quantity__c);
    }
}
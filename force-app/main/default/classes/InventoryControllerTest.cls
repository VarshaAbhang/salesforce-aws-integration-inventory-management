@isTest
private class InventoryControllerTest {

    @testSetup
    static void setupData() {
        Product__c product = new Product__c(
            Name = 'Test Product',
            Category__c = 'Electronics',
            SKU__c = 'TEST-SKU-001',
            Stock_Quantity__c = 20
        );
        insert product;

        Location__c location = new Location__c(
            Name = 'Test Location'
        );
        insert location;

        Inventory__c inventory = new Inventory__c(
            Name = 'Test Inventory',
            Quantity__c = 20,
            Status__c = 'Available',
            Product__c = product.Id,
            Inventory_Location__c = location.Id,
            SyncedWithDynamo__c = false
        );
        insert inventory;
    }

    @isTest
    static void testGetInventoryDataWithoutFilters() {
        Test.startTest();
        List<Inventory__c> results =
            InventoryController.getInventoryData(null, null);
        Test.stopTest();

        System.assertEquals(1, results.size());
    }

    @isTest
    static void testGetInventoryDataWithSearch() {
        Test.startTest();
        List<Inventory__c> results =
            InventoryController.getInventoryData('TEST-SKU', null);
        Test.stopTest();

        System.assertEquals(1, results.size());
    }

    @isTest
    static void testGetInventoryDataWithStatus() {
        Test.startTest();
        List<Inventory__c> results =
            InventoryController.getInventoryData(null, 'Available');
        Test.stopTest();

        System.assertEquals(1, results.size());
    }

    @isTest
    static void testGetProducts() {
        Test.startTest();
        List<Product__c> results = InventoryController.getProducts();
        Test.stopTest();

        System.assertEquals(1, results.size());
    }

    @isTest
    static void testGetLocations() {
        Test.startTest();
        List<Location__c> results = InventoryController.getLocations();
        Test.stopTest();

        System.assertEquals(1, results.size());
    }
}

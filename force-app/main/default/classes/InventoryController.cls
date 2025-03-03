public with sharing class InventoryController {
    @AuraEnabled(cacheable=true)
    public static List<Inventory__c> getInventoryData(String searchValue, String status) {
        String query = 'SELECT Id, Name, Quantity__c, Status__c, Last_Updated__c, Product__r.Name, Product__r.SKU__c, Inventory_Location__r.Name, SyncedWithDynamo__c FROM Inventory__c';
        
        List<String> conditions = new List<String>();

        // Search both SKU and Product Name in the same input field
        if (!String.isEmpty(searchValue)) {
            conditions.add('(Product__r.SKU__c LIKE \'%' + searchValue + '%\' OR Product__r.Name LIKE \'%' + searchValue + '%\')');
        }

        // If status is provided, filter by Status
        if (!String.isEmpty(status)) {
            conditions.add('Status__c = :status');
        }

        // Append WHERE conditions
        if (!conditions.isEmpty()) {
            query += ' WHERE ' + String.join(conditions, ' AND ');
        }

        return Database.query(query);
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Product__c> getProducts() {
        return [SELECT Id, Name FROM Product__c];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Location__c> getLocations() {
        return [SELECT Id, Name FROM Location__c];
    }
}
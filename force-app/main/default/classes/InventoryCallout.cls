public class InventoryCallout {

    @future(callout=true)
       public static void insertToDynamoDB(List<Id> inventoryIds) {
        List<Inventory__c> inventories = [SELECT Id, Name, Quantity__c, Status__c, Last_Updated__c, SyncedWithDynamo__c,
                                          Product__c, Product__r.Name, Product__r.Stock_Quantity__c, Product__r.SKU__c, Product__r.Category__c,Product__r.Price__c, Product__r.Barcode_QR_Code__c, 
                                          Product__r.Cost__c, Product__r.Product_Status__c, 
                                          Product__r.Supplier__c, Product__r.Supplier__r.Name, 
                                          Product__r.Supplier_s_Contact__c,Product__r.Supplier_s_Contact__r.Name, 
                                          Product__r.Product_Condition__c, Product__r.Lead_Time__c, Product__r.Expiration_Date__c, Product__r.Location_of_Product__c, Product__r.Reorder_Level__c,
                                          Inventory_Location__c, Inventory_Location__r.Name, Inventory_Location__r.Warehouse_Name__c, Inventory_Location__r.Aisle_Section__c, Inventory_Location__r.Location_Capacity__c
                                          FROM Inventory__c 
                                          WHERE Id IN :inventoryIds];
    
        List<Map<String, Object>> inventoryBatchPayload = new List<Map<String, Object>>();
        
        for (Inventory__c inv : inventories) {
            Map<String, Object> payload = new Map<String, Object>();
            payload.put('InventoryId', inv.Id);
            payload.put('SalesforceInventoryId', inv.Id);
            payload.put('InventoryName', inv.Name);
			payload.put('Quantity', inv.Quantity__c);
            payload.put('Status', inv.Status__c);
            payload.put('Source', 'fromSalesforce');
            payload.put('Product', new Map<String, Object>{
                'ProductId'=> inv.Product__c,
                'ProductName'=> inv.Product__r.Name,
                'StockQuantity'=> inv.Product__r.Stock_Quantity__c,
                'SKU'=> inv.Product__r.SKU__c,
                'Category' => inv.Product__r.Category__c,
                'Price' => inv.Product__r.Price__c,
                'Barcode_QR_Code' => inv.Product__r.Barcode_QR_Code__c,
                'Cost' => inv.Product__r.Cost__c,
                'ProductStatus' => inv.Product__r.Product_Status__c,
                'Supplier' => inv.Product__r.Supplier__r.Name,
                'Supplier_s_Contact' => inv.Product__r.Supplier_s_Contact__r.Name,
                'Product_Condition' => inv.Product__r.Product_Condition__c,
                'Lead_Time' => inv.Product__r.Lead_Time__c,
                'Expiration_Date' => inv.Product__r.Expiration_Date__c,
                'Location_of_Product' => inv.Product__r.Location_of_Product__c,
                'Reorder_Level' => inv.Product__r.Reorder_Level__c,
                'SalesforceProductId' => inv.Product__c
            });
            payload.put('Location', new Map<String, Object> {
                'LocationId' => inv.Inventory_Location__c,
                'LocationName' => inv.Inventory_Location__r.Name,
                'WarehouseName' => inv.Inventory_Location__r.Warehouse_Name__c,
                'AisleSection' => inv.Inventory_Location__r.Aisle_Section__c,
                'LocationCapacity' => inv.Inventory_Location__r.Location_Capacity__c,
                'SalesforceLocationId' => inv.Inventory_Location__c  
            });
            inventoryBatchPayload.add(payload);
        }
    
        // Send all records in a single request
        if (!inventoryBatchPayload.isEmpty()) {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:AWS_Lambda_API_Named/inventory');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(inventoryBatchPayload));
    
            Http http = new Http();
            try {
                HttpResponse res = http.send(req);
                System.debug('Response Status: ' + res.getStatus());
                System.debug('Response Body: ' + res.getBody());
            } catch (Exception e) {
                System.debug('Callout failed: ' + e.getMessage());
            }
        }
    }


    @future(callout=true)
    public static void updateToDynamoDB(List<Id> inventoryIds) {
        Integer batchSize = 10; // Define the batch size
        Integer totalRecords = inventoryIds.size();
        
        // Iterate through the list and process in chunks
        for (Integer i = 0; i < totalRecords; i += batchSize) {
            Integer endIndex = Math.min(i + batchSize, totalRecords);
            List<Id> batch = new List<Id>();
            
            // Manually slice the list from i to endIndex
            for (Integer j = i; j < endIndex; j++) {
                batch.add(inventoryIds[j]);
            }
            
            // Call the method with the batch of IDs
            processBatch(batch);
        }
    }
    
    private static void processBatch(List<Id> batchIds) {
        List<Inventory__c> inventories = [SELECT Id, Name, Quantity__c, Status__c,
                                          Product__c, Product__r.Name, Product__r.Stock_Quantity__c, Product__r.SKU__c, Product__r.Category__c,
                                          Inventory_Location__c, Inventory_Location__r.Name, Inventory_Location__r.Aisle_Section__c, Inventory_Location__r.Location_Capacity__c, 
                                          Inventory_Location__r.Warehouse_Name__c
                                          FROM Inventory__c 
                                          WHERE Id IN :batchIds];
        
        for (Inventory__c inv : inventories) {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:AWS_Lambda_API_Named/inventory');
            req.setMethod('PUT');
            req.setHeader('Content-Type', 'application/json');
            
            Map<String, Object> payload = new Map<String, Object>();
              payload.put('inventoryItems', new List<Map<String, Object>> {
                new Map<String, Object> {
                    'InventoryId' => inv.Id,
                    'InventoryName' => inv.Name,
                    'Quantity' => inv.Quantity__c,
                    'Status' => inv.Status__c,
                    'Location' => new Map<String, Object> {
                        'LocationId' => inv.Inventory_Location__c,
                        'LocationName' => inv.Inventory_Location__r.Name,
                        'AisleSection' => inv.Inventory_Location__r.Aisle_Section__c,
                        'LocationCapacity' => inv.Inventory_Location__r.Location_Capacity__c,
                        'WarehouseName' => inv.Inventory_Location__r.Warehouse_Name__c
                    },
                    'Product' => new Map<String, Object> {
                        'ProductId' => inv.Product__c,
                        'ProductName' => inv.Product__r.Name,
                        'SKU' => inv.Product__r.SKU__c,
                        'Category' => inv.Product__r.Category__c
                    }
                }
            });
            
            req.setBody(JSON.serialize(payload));
            
            Http http = new Http();
            try {
                HttpResponse res = http.send(req);
                System.debug('Response Status: ' + res.getStatus());
                System.debug('Response Body: ' + res.getBody());
            } catch (Exception e) {
                System.debug('Callout failed: ' + e.getMessage());
            }
        }
    }

    
    @future(callout=true)
    public static void deleteToDynamoDB(List<Id> inventoryIds) {
        if (inventoryIds == null || inventoryIds.isEmpty()) {
            System.debug('No inventory IDs to delete from DynamoDB.');
            return;
        }
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:AWS_Lambda_API_Named/inventory');
        req.setMethod('DELETE');
        req.setHeader('Content-Type', 'application/json');
        
        // ✅ Make sure we're sending "InventoryIds" (plural) as an array
        Map<String, Object> payload = new Map<String, Object>();
        payload.put('InventoryIds', inventoryIds);  
        
        req.setBody(JSON.serialize(payload));
        
        Http http = new Http();
        try {
            HttpResponse res = http.send(req);
            System.debug('Response Status: ' + res.getStatus());
            System.debug('Response Body: ' + res.getBody());
        } catch (Exception e) {
            System.debug('Callout failed: ' + e.getMessage());
        }
    }
    
        

}
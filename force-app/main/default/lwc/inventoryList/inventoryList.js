import { LightningElement, track, wire, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import getInventoryData from '@salesforce/apex/InventoryController.getInventoryData';
import getProducts from '@salesforce/apex/InventoryController.getProducts';
import getLocations from '@salesforce/apex/InventoryController.getLocations';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import INVENTORY_OBJECT from '@salesforce/schema/Inventory__c';
import STATUS_FIELD from '@salesforce/schema/Inventory__c.Status__c';
import { createRecord, deleteRecord, updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

const ACTIONS = [
    // { label: 'Edit', name: 'edit' },
    { label: 'Delete', name: 'delete' }
];

const columns = [
    { label: 'Inventory Name', fieldName: 'Name' },
    { 
        label: 'Product Name', 
        fieldName: 'productUrl', 
        type: 'url', 
        typeAttributes: { label: { fieldName: 'Product__r.Name' }, target: '_blank' } 
    },
    { label: 'SKU', fieldName: 'Product__r.SKU__c' },
    { 
        label: 'Status', 
        fieldName: 'Status__c', 
        type: 'customPicklist',
        editable: true,
        typeAttributes: {
            options: { fieldName: 'picklistOptions' },
            value: { fieldName: 'Status__c' },
            context: { fieldName: 'Id' }
        }
    },
    { label: 'Quantity', fieldName: 'Quantity__c', editable: true },
    { 
        label: 'Location', 
        fieldName: 'locationUrl', 
        type: 'url', 
        typeAttributes: { label: { fieldName: 'Inventory_Location__r.Name' }, target: '_blank' }
    },
    { 
        label: 'Last Updated', 
        fieldName: 'Last_Updated__c', 
        type: 'date',
        typeAttributes: {
            day: '2-digit', 
            month: '2-digit', 
            year: 'numeric', 
            hour: '2-digit', 
            minute: '2-digit', 
            hour12: true
        }
    },
    { label: 'Synced With AWS?', fieldName: 'SyncedWithDynamo__c', type: 'boolean', editable: true },
    {
        type: 'action',
        typeAttributes: { rowActions: ACTIONS }
    }
];

export default class InventoryList extends NavigationMixin(LightningElement) {
    @track inventoryData = [];
    columns = columns;
    @track allInventoryData = [];
    @track searchSKU = '';
    @track statusFilter = '';
    @track sortedBy;
    @track sortedDirection = 'asc';
    @track statusOptions = []; 
    @track draftValues = [];

    @track newInventoryName = '';
    @track newQuantity = '';
    @track selectedStatus = '';
    @track selectedProduct = '';
    @track selectedLocation = '';
    @track isSynced = false;

    @track productOptions = [];
    @track locationOptions = []; 
    wiredInventoryResult; 

    @track currentPage = 1;
    @track recordsPerPage = 10;
    @track totalRecords = 0;

    inventoryChannel = '/event/Inventory_Updated__e';


  /*******************************************************/

    @wire(getObjectInfo, { objectApiName: INVENTORY_OBJECT })
    inventoryObjectInfo;

    @wire(getPicklistValues, { 
        recordTypeId: '$inventoryObjectInfo.data.defaultRecordTypeId', 
        fieldApiName: STATUS_FIELD 
    })
    wiredStatusPicklist({ data, error }) {
        if (data) {
            this.statusOptions = [{ label: 'All', value: '' }, ...data.values.map(item => ({
                label: item.label,
                value: item.value
            }))];

            // ✅ Ensure the table updates AFTER picklist values are set
            if (this.allInventoryData.length > 0) {
                this.updateTableData(this.allInventoryData);
            }
        } else if (error) {
            console.error('Error fetching picklist values for Status__c:', error);
        }
    }
    

    @wire(getInventoryData)
    getwiredInventorydata(result) {
        this.wiredInventoryResult = result;
        const { error, data } = result;
        if (data) {
            this.allInventoryData = data;
            this.totalRecords = data.length;
            this.updateTableData(this.allInventoryData);
        } else if (error) {
            console.error('Error fetching Inventory data', error);
        }
    }

    connectedCallback() {
        this.subscribeToInventoryEvent();
        this.fetchProductOptions();
        this.fetchLocationOptions();
    }
    
    
    subscribeToInventoryEvent() {
        subscribe(this.inventoryChannel, -1, (event) => {
            console.log('Received Inventory Update Event:', event);
            this.handleInventoryUpdate(event);
        })
        .then(response => {
            console.log('Subscribed to Inventory Update Event', response);
        })
        .catch(error => {
            console.error('Error subscribing to Inventory Event:', error);
        });
    }

    handleInventoryUpdate(event) {
        console.log('Event Payload:', JSON.stringify(event.data.payload, null, 2));
        const inventoryId = event.data.payload.InventoryId__c;
        const quantity = event.data.payload.Quantity__c;
        const status = event.data.payload.Status__c;
        const alertType = event.data.payload.AlertType__c;
    
        let isNew = true;
        this.allInventoryData = this.allInventoryData.map(item => {
            if (item.Id === inventoryId) {
                isNew = false;
                return { ...item, Quantity__c: quantity, Status__c: status };
            }
            return item;
        });
    
        if (isNew) {
            // Handle new inventory creation if needed
        }
    
        this.inventoryData = this.inventoryData.map(item => {
            if (item.Id === inventoryId) {
                return { ...item, Quantity__c: quantity, Status__c: status };
            }
            return item;
        });
    
        this.inventoryData = [...this.inventoryData]; 
    
        const action = isNew ? 'Created' : 'Updated';
        this.showToast(
            `📢 Inventory ${action}! 📢`,
            `Inventory ID ${inventoryId} is now ${quantity} units with status: ${status}`,
            'success'
        );
    
        // Show alert notifications based on alertType
        if (alertType) {
            let alertMessage = `Inventory ID ${inventoryId} has a ${alertType} alert. Quantity: ${quantity}.`;
            let variant = 'info'; // Default variant
    
            if (alertType === 'Out Of Stock') {
                variant = 'error';
                alertMessage = `Inventory ID ${inventoryId} is out of stock! Quantity: ${quantity}.`;
            } else if (alertType === 'Low Stock') {
                variant = 'warning';
                alertMessage = `Inventory ID ${inventoryId} is running low! Quantity: ${quantity}.`;
            }
    
            // Log the alert message to the console
            console.log(`🚨 ${alertType} Alert! 🚨`, alertMessage, variant);
    
            this.showToast(`🚨 ${alertType} Alert! 🚨`, alertMessage, variant);
        }
    
        refreshApex(this.wiredInventoryResult);
    }
    
    showToast(title, message, variant) {
        // Log the toast message to the console
        console.log(`Toast Message - Title: ${title}, Message: ${message}, Variant: ${variant}`);
    
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
    

    updateTableData(data) { 
        // if (!this.statusOptions || this.statusOptions.length === 0) {
        //     console.warn('⚠️ Picklist options not available yet!');
        //     return; // Wait until picklist options are available
        // }
    
        const startIndex = (this.currentPage - 1) * this.recordsPerPage;
        const endIndex = startIndex + this.recordsPerPage;     
        this.inventoryData = data.slice(startIndex, endIndex).map((item, index) => ({
            ...item,
            'Product__r.Name': item.Product__r?.Name || '',
            'Product__r.SKU__c': item.Product__r?.SKU__c || '',
            'Inventory_Location__r.Name': item.Inventory_Location__r?.Name || '',
            picklistOptions: [...this.statusOptions],
            rowNumber: startIndex + index + 1,
    
            // ✅ Add URLs for Product & Location
            productUrl: item.Product__c ? `/lightning/r/Product__c/${item.Product__c}/view` : '',
            locationUrl: item.Inventory_Location__c ? `/lightning/r/Inventory_Location__c/${item.Inventory_Location__c}/view` : ''
        }));
        //console.log('Updated Data Table:', JSON.stringify(this.inventoryData));
    }    

    handleInventoryNameChange(event) {
        this.newInventoryName = event.target.value;
    }

    handleStatusChange(event) {
        this.selectedStatus = event.target.value;
    }

    handleQuantityChange(event) {
        this.newQuantity = event.target.value;
    }

    handleProductChange(event) {
        if (event.target.value === 'createNew') {
            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: {
                    objectApiName: 'Product__c',
                    actionName: 'new'
                }
            });
        } else {
            this.selectedProduct = event.target.value;
        }
    }
    
    handleLocationChange(event) {
        if (event.target.value === 'createNew') {
            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: {
                    objectApiName: 'Location__c',
                    actionName: 'new'
                }
            });
        } else {
            this.selectedLocation = event.target.value;
        }
    }
    

    handleSyncChange(event) {
        this.isSynced = event.target.checked;
    }

    async handleCreateInventory() {
        const fields = {
            Name: this.newInventoryName,
            Status__c: this.selectedStatus,
            Quantity__c: this.newQuantity,
            Product__c: this.selectedProduct,
            Inventory_Location__c: this.selectedLocation,
            SyncedWithDynamo__c: this.isSynced
        };
    
        const recordInput = { apiName: 'Inventory__c', fields };
    
        try {
            await createRecord(recordInput);
            this.showToast('Success', 'Inventory created successfully', 'success');
            await refreshApex(this.wiredInventoryResult);
            this.resetCreateForm();
        } catch (error) {
            this.showToast('Error', 'Failed to create inventory record', 'error');
        }
    }
    

    resetCreateForm() {
        this.newInventoryName = '';
        this.selectedStatus = '';
        this.newQuantity = '';
        this.selectedProduct = '';
        this.selectedLocation = '';
        this.isSynced = false;
    }

    fetchProductOptions() {
        getProducts()
            .then(data => {
                this.productOptions = [
                    ...data.map(item => ({
                        label: item.Name,
                        value: item.Id
                    })),
                    { label: '+ New Custom Product', value: 'createNew' } 
                ];
            })
            .catch(error => {
                console.error('Error fetching product options:', error);
            });
    }
    
    fetchLocationOptions() {
        getLocations()
            .then(data => {
                this.locationOptions = [
                    ...data.map(item => ({
                        label: item.Name,
                        value: item.Id
                    })),
                    { label: '+ New Custom Location', value: 'createNew' } 
                ];
            })
            .catch(error => {
                console.error('Error fetching location options:', error);
            });
    }
    
    
    handleSearchChange(event) {
        this.searchSKU = event.target.value;
        this.currentPage = 1;
        this.filterData();
    }

    handleStatusFilterChange(event) {
        this.statusFilter = event.target.value;
        this.currentPage = 1;
        this.filterData();
    }

    filterData() {
        let filteredData = [...this.allInventoryData];

        if (this.statusFilter) {
            filteredData = filteredData.filter(item => item.Status__c === this.statusFilter);
        }

        if (this.searchSKU) {
            let searchLower = this.searchSKU.toLowerCase();
            filteredData = filteredData.filter(item =>
                (item.Product__r.Name && item.Product__r.Name.toLowerCase().includes(searchLower)) || 
                (item.Product__r.SKU__c && item.Product__r.SKU__c.toLowerCase().includes(searchLower))
            );
        }
        
        console.log('All Inventory Data:', JSON.stringify(this.allInventoryData));

        this.totalRecords = filteredData.length;
        this.updateTableData(filteredData);
    }

    handleSort(event) {
        const { fieldName, sortDirection } = event.detail;
        this.inventoryData = [...this.inventoryData].sort((a, b) => {
            let valueA = a[fieldName] || '';
            let valueB = b[fieldName] || '';
            return sortDirection === 'asc' ? valueA.localeCompare(valueB) : valueB.localeCompare(valueA);
        });
        this.sortedBy = fieldName;
        this.sortedDirection = sortDirection;
    }

    handleNextPage() {
        if (this.currentPage * this.recordsPerPage < this.totalRecords) {
            this.currentPage++;
            this.updateTableData(this.allInventoryData);
        }
    }
    
    handlePrevPage() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.updateTableData(this.allInventoryData);
        }
    }
    

    get isFirstPage() {
        return this.currentPage === 1;
    }

    get isLastPage() {
        return this.currentPage * this.recordsPerPage >= this.totalRecords;
    }


    async handleInventorysSave(event) {
        const updatePromises = event.detail.draftValues.map(record => {
            const fields = { ...record }; 
            return updateRecord({ fields });
        });
    
        try {
            await Promise.all(updatePromises);
            this.showToast('Success', 'Inventory data updated successfully', 'success');
            this.draftValues = [];
            await refreshApex(this.wiredInventoryResult);
        } catch (error) {
            this.showToast('Error', 'Failed to update inventory records', 'error');
        }
    }

    rowActionHandler(event) {
        const actionName = event.detail.action;
        const row = event.detail.row;
    
        console.log('Row Data:', JSON.stringify(row));
    
        this.selectedRecordId = row.Id;
        console.log('Selected row id:', this.selectedRecordId);
    
        this.viewMode = false;
        this.editMode = false;
        this.showModal = false;
    
    //     if (actionName.name === 'view') {
    //         this.viewMode = true;
    //         this.showModal = true;
    //     } else if (actionName.name === 'edit') {
    //         this.editMode = true;
    //         this.showModal = true;
     //    } 
    if (actionName.name === 'delete') {
             this.deleteHandler();
         }
    }
    

    async deleteHandler() {
        try {
            await deleteRecord(this.selectedRecordId);
            this.showToast('Success', 'Record deleted successfully', 'success');
            await refreshApex(this.wiredInventoryResult);
        } catch (error) {
            this.showToast('Error', 'Failed to delete record', 'error');
        }
    }

    // async closemodal(event)
    // {
    //     this.showModal = false;
    //     if(this.editMode)
    //     {
    //         await refreshApex(this.wiredDimensionDataResult);
    //     }
    // }
}
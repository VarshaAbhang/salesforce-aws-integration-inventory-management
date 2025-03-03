import LightningDataTable from 'lightning/datatable';
import customPicklist from './customPicklist.html';
import customPicklistEdit from './customPicklistEdit.html';

export default class CustomDataType extends LightningDataTable {
static customTypes = {
    customPicklist :
    {
            template: customPicklist,
            editTemplate: customPicklistEdit,
            standardCellLayout: true,
            typeAttributes: ['options','value','context']
    }   
}

}
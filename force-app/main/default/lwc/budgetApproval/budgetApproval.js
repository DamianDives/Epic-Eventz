import { LightningElement, wire, track } from 'lwc';
import getEventsForApproval from '@salesforce/apex/BudgetApprovalController.getEventsForApproval';
import getAllEventsForSubmission from '@salesforce/apex/BudgetApprovalController.getAllEventsForSubmission';
import submitForApproval from '@salesforce/apex/BudgetApprovalController.submitForApproval';
import approveEvent from '@salesforce/apex/BudgetApprovalController.approveEvent';
import rejectEvent from '@salesforce/apex/BudgetApprovalController.rejectEvent';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

const SUBMIT_COLUMNS = [
    { label: 'Event Name', fieldName: 'Name', type: 'text' },
    { label: 'Type', fieldName: 'Event_Type__c', type: 'text' },
    { label: 'Budget', fieldName: 'Budget__c', type: 'currency' },
    { label: 'Start Date', fieldName: 'Start_Date__c', type: 'date' },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [{ label: 'Submit', name: 'submit' }]
        }
    }
];

const APPROVAL_COLUMNS = [
    { label: 'Event Name', fieldName: 'Name', type: 'text' },
    { label: 'Type', fieldName: 'Event_Type__c', type: 'text' },
    { label: 'Budget', fieldName: 'Budget__c', type: 'currency' },
    { label: 'Start Date', fieldName: 'Start_Date__c', type: 'date' },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'Approve', name: 'approve' },
                { label: 'Reject', name: 'reject' }
            ]
        }
    }
];

export default class BudgetApproval extends LightningElement {
    @track pendingEvents = null;
    @track draftEvents = null;
    @track showModal = false;
    @track modalTitle = '';
    @track modalActionLabel = '';
    @track modalVariant = 'brand';
    @track selectedEventId = null;
    @track selectedEventName = '';
    @track selectedEventBudget = '';
    @track comments = '';
    @track actionType = '';
    
    submitColumns = SUBMIT_COLUMNS;
    approvalColumns = APPROVAL_COLUMNS;
    wiredPending;
    wiredDrafts;

    @wire(getEventsForApproval)
    wiredPendingEvents(result) {
        this.wiredPending = result;
        if (result.data) {
            this.pendingEvents = result.data.length > 0 ? result.data : null;
        }
    }

    @wire(getAllEventsForSubmission)
    wiredDraftEvents(result) {
        this.wiredDrafts = result;
        if (result.data) {
            this.draftEvents = result.data.length > 0 ? result.data : null;
        }
    }

    handleSubmitAction(event) {
        const row = event.detail.row;
        this.selectedEventId = row.Id;
        this.selectedEventName = row.Name;
        this.selectedEventBudget = '$' + (row.Budget__c || 0).toLocaleString();
        this.comments = '';
        this.modalTitle = 'Submit for Budget Approval';
        this.modalActionLabel = 'Submit';
        this.modalVariant = 'brand';
        this.actionType = 'submit';
        this.showModal = true;
    }

    handleApprovalAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;
        this.selectedEventId = row.Id;
        this.selectedEventName = row.Name;
        this.selectedEventBudget = '$' + (row.Budget__c || 0).toLocaleString();
        this.comments = '';
        
        if (action.name === 'approve') {
            this.modalTitle = 'Approve Budget';
            this.modalActionLabel = 'Approve';
            this.modalVariant = 'success';
            this.actionType = 'approve';
        } else {
            this.modalTitle = 'Reject Budget';
            this.modalActionLabel = 'Reject';
            this.modalVariant = 'destructive';
            this.actionType = 'reject';
        }
        this.showModal = true;
    }

    handleCommentsChange(event) {
        this.comments = event.target.value;
    }

    closeModal() {
        this.showModal = false;
    }

    async handleConfirmAction() {
        this.showModal = false;
        try {
            let result;
            if (this.actionType === 'submit') {
                result = await submitForApproval({ eventId: this.selectedEventId, comments: this.comments });
            } else if (this.actionType === 'approve') {
                result = await approveEvent({ eventId: this.selectedEventId, comments: this.comments });
            } else {
                result = await rejectEvent({ eventId: this.selectedEventId, comments: this.comments });
            }
            
            const variant = result.success ? 'success' : 'error';
            this.dispatchEvent(new ShowToastEvent({
                title: result.success ? 'Success' : 'Error',
                message: result.message,
                variant: variant
            }));
            
            await refreshApex(this.wiredPending);
            await refreshApex(this.wiredDrafts);
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body ? error.body.message : error.message,
                variant: 'error'
            }));
        }
    }
}

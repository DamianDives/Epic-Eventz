import { LightningElement, wire, track } from 'lwc';
import getEventsForApproval from '@salesforce/apex/BudgetApprovalController.getEventsForApproval';
import getAllEventsForSubmission from '@salesforce/apex/BudgetApprovalController.getAllEventsForSubmission';
import submitForApproval from '@salesforce/apex/BudgetApprovalController.submitForApproval';
import approveEvent from '@salesforce/apex/BudgetApprovalController.approveEvent';
import rejectEvent from '@salesforce/apex/BudgetApprovalController.rejectEvent';
import checkFinanceAccess from '@salesforce/apex/BudgetApprovalController.checkFinanceAccess';
import { refreshApex } from '@salesforce/apex';

export default class BudgetApproval extends LightningElement {
    @track pendingEvents = null;
    @track draftEvents = null;
    @track hasFinanceAccess = false;
    @track showToast = false;
    @track toastMessage = '';
    @track toastClass = 'toast toast-success';
    wiredPending; wiredDrafts;

    @wire(checkFinanceAccess)
    wiredAccess({ data }) {
        if (data !== undefined) this.hasFinanceAccess = data;
    }

    @wire(getEventsForApproval)
    wiredPendingEvents(result) {
        this.wiredPending = result;
        if (result.data) this.pendingEvents = result.data.length > 0 ? result.data : null;
    }

    @wire(getAllEventsForSubmission)
    wiredDraftEvents(result) {
        this.wiredDrafts = result;
        if (result.data) this.draftEvents = result.data.length > 0 ? result.data : null;
    }

    get pendingCount() { return this.pendingEvents ? this.pendingEvents.length : 0; }

    async handleSubmit(event) {
        const eventId = event.currentTarget.dataset.id;
        const result = await submitForApproval({ eventId, comments: '' });
        this.showNotification(result.success, result.message);
        await refreshApex(this.wiredPending);
        await refreshApex(this.wiredDrafts);
    }

    async handleApprove(event) {
        const eventId = event.currentTarget.dataset.id;
        const result = await approveEvent({ eventId, comments: '' });
        this.showNotification(result.success, result.message);
        await refreshApex(this.wiredPending);
        await refreshApex(this.wiredDrafts);
    }

    async handleReject(event) {
        const eventId = event.currentTarget.dataset.id;
        const result = await rejectEvent({ eventId, comments: '' });
        this.showNotification(result.success, result.message);
        await refreshApex(this.wiredPending);
        await refreshApex(this.wiredDrafts);
    }

    showNotification(success, message) {
        this.toastMessage = message;
        this.toastClass = success ? 'toast toast-success' : 'toast toast-error';
        this.showToast = true;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this.showToast = false; }, 3500);
    }
}

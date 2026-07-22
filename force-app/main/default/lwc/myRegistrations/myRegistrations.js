import { LightningElement, wire, track } from 'lwc';
import getMyRegistrations from '@salesforce/apex/MyRegistrationsController.getMyRegistrations';
import cancelRegistration from '@salesforce/apex/MyRegistrationsController.cancelRegistration';
import getCurrentUserEmail from '@salesforce/apex/MyRegistrationsController.getCurrentUserEmail';
import { refreshApex } from '@salesforce/apex';

export default class MyRegistrations extends LightningElement {
    @track registrations = [];
    @track showConfirmModal = false;
    @track cancelRegId = null;
    @track showToast = false;
    @track toastMessage = '';
    @track toastClass = '';
    userEmail = '';
    wiredResult;

    @wire(getCurrentUserEmail)
    wiredEmail({ data }) {
        if (data) { this.userEmail = data; }
    }

    @wire(getMyRegistrations, { email: '$userEmail' })
    wiredRegs(result) {
        this.wiredResult = result;
        if (result.data) {
            this.registrations = result.data.map(reg => ({
                ...reg,
                formattedDate: this.formatDate(reg.startDate, reg.endDate),
                isWaitlisted: reg.status === 'Waitlisted',
                statusClass: reg.status === 'Confirmed'
                    ? 'status-badge confirmed'
                    : 'status-badge waitlisted'
            }));
        }
    }

    get hasRegistrations() {
        return this.registrations && this.registrations.length > 0;
    }

    formatDate(start, end) {
        if (!start) return 'TBD';
        const s = new Date(start);
        const opts = { month: 'short', day: 'numeric', year: 'numeric' };
        let r = s.toLocaleDateString('en-US', opts);
        if (end) {
            const e = new Date(end);
            if (s.toDateString() !== e.toDateString()) {
                r += ' – ' + e.toLocaleDateString('en-US', opts);
            }
        }
        return r;
    }

    handleCancel(event) {
        this.cancelRegId = event.currentTarget.dataset.id;
        this.showConfirmModal = true;
    }

    closeModal() {
        this.showConfirmModal = false;
        this.cancelRegId = null;
    }

    async confirmCancel() {
        this.showConfirmModal = false;
        try {
            const result = await cancelRegistration({ regId: this.cancelRegId });
            if (result.success) {
                this.showToastMsg('success', result.message);
                await refreshApex(this.wiredResult);
            } else {
                this.showToastMsg('error', result.message);
            }
        } catch (error) {
            this.showToastMsg('error', error.body ? error.body.message : 'Error cancelling.');
        }
        this.cancelRegId = null;
    }

    showToastMsg(type, msg) {
        this.toastMessage = msg;
        this.toastClass = type === 'success' ? 'toast toast-success' : 'toast toast-error';
        this.showToast = true;
        setTimeout(() => { this.showToast = false; }, 4000);
    }
}

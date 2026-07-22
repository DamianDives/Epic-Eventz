import { LightningElement, wire, track } from 'lwc';
import isGuest from '@salesforce/user/isGuest';
import getPublishedEvents from '@salesforce/apex/RegistrationController.getPublishedEvents';
import registerForEvent from '@salesforce/apex/RegistrationController.registerForEvent';

export default class EventRegistration extends LightningElement {
    isGuestUser = isGuest;
    @track currentStep = 1;
    @track events = [];
    @track selectedEventId = null;
    @track attendeeName = '';
    @track email = '';
    @track phone = '';
    @track company = '';
    @track regAmount = null;
    @track isLoading = false;
    @track registrationSuccess = false;
    @track registrationError = false;
    @track resultStatus = '';
    @track waitlistPosition = null;
    @track regNumber = '';
    @track errorMessage = '';

    @wire(getPublishedEvents)
    wiredEvents({ error, data }) {
        if (data) {
            this.events = data.map(evt => ({
                ...evt,
                venueName: evt.Venue__r
                    ? `${evt.Venue__r.City__c}, ${evt.Venue__r.State__c}`
                    : 'Location TBD',
                formattedDate: this.formatDate(evt.Start_Date__c, evt.End_Date__c),
                seatsInfo: evt.Max_Capacity__c
                    ? `${evt.Max_Capacity__c} seats` : 'Unlimited',
                isSelected: false,
                cardClass: 'event-card'
            }));
        } else if (error) {
            console.error('Error loading events:', error);
        }
    }

    formatDate(startDate, endDate) {
        if (!startDate) return 'Date TBD';
        const start = new Date(startDate);
        const opts = { month: 'short', day: 'numeric', year: 'numeric' };
        let result = start.toLocaleDateString('en-US', opts);
        if (endDate) {
            const end = new Date(endDate);
            if (start.toDateString() !== end.toDateString()) {
                result += ' – ' + end.toLocaleDateString('en-US', opts);
            }
        }
        return result;
    }

    // Step getters
    get isStep1() { return this.currentStep === 1; }
    get isStep2() { return this.currentStep === 2; }
    get isStep3() { return this.currentStep === 3; }
    get hasEvents() { return this.events && this.events.length > 0; }
    get isNextDisabled() { return !this.selectedEventId; }
    get isRegisterDisabled() {
        return !this.attendeeName || !this.email || !this.regAmount || this.isLoading;
    }
    get isWaitlisted() { return this.resultStatus === 'Waitlisted'; }

    // Progress step classes
    get step1Class() {
        if (this.currentStep > 1) return 'step completed';
        if (this.currentStep === 1) return 'step active';
        return 'step';
    }
    get step2Class() {
        if (this.currentStep > 2) return 'step completed';
        if (this.currentStep === 2) return 'step active';
        return 'step';
    }
    get step3Class() {
        if (this.currentStep === 3) return 'step active';
        return 'step';
    }
    get statusClass() {
        return this.resultStatus === 'Confirmed'
            ? 'status-confirmed' : 'status-waitlisted';
    }

    // Event handlers
    handleEventSelect(event) {
        this.selectedEventId = event.currentTarget.dataset.id;
        this.events = this.events.map(evt => ({
            ...evt,
            isSelected: evt.Id === this.selectedEventId,
            cardClass: evt.Id === this.selectedEventId
                ? 'event-card selected' : 'event-card'
        }));
    }

    handleNameChange(event) { this.attendeeName = event.target.value; }
    handleEmailChange(event) { this.email = event.target.value; }
    handlePhoneChange(event) { this.phone = event.target.value; }
    handleCompanyChange(event) { this.company = event.target.value; }
    handleAmountChange(event) { this.regAmount = event.target.value; }

    goToStep1() { this.currentStep = 1; }
    goToStep2() {
        if (!this.selectedEventId) return;
        // If guest user, redirect to login page
        if (this.isGuestUser) {
            const currentPath = window.location.pathname;
            const basePath = currentPath.substring(0, currentPath.indexOf('/s/') + 3);
            const loginUrl = basePath + 'login?startURL=' +
                encodeURIComponent(currentPath + '?eventId=' + this.selectedEventId);
            window.location.href = loginUrl;
            return;
        }
        this.currentStep = 2;
    }

    async handleRegister() {
        if (!this.attendeeName || !this.email || !this.regAmount) return;
        this.isLoading = true;
        try {
            const result = await registerForEvent({
                eventId: this.selectedEventId,
                attendeeName: this.attendeeName,
                email: this.email,
                phone: this.phone,
                company: this.company,
                regAmount: parseFloat(this.regAmount)
            });
            if (result.success) {
                this.registrationSuccess = true;
                this.registrationError = false;
                this.resultStatus = result.status;
                this.waitlistPosition = result.waitlistPosition;
                this.regNumber = result.regNumber;
            } else {
                this.registrationSuccess = false;
                this.registrationError = true;
                this.errorMessage = result.errorMessage;
            }
            this.currentStep = 3;
        } catch (error) {
            this.registrationSuccess = false;
            this.registrationError = true;
            this.errorMessage = error.body ? error.body.message : error.message;
            this.currentStep = 3;
        } finally {
            this.isLoading = false;
        }
    }

    handleReset() {
        this.currentStep = 1;
        this.selectedEventId = null;
        this.attendeeName = '';
        this.email = '';
        this.phone = '';
        this.company = '';
        this.regAmount = null;
        this.registrationSuccess = false;
        this.registrationError = false;
        this.resultStatus = '';
        this.waitlistPosition = null;
        this.regNumber = '';
        this.errorMessage = '';
        this.events = this.events.map(evt => ({
            ...evt, isSelected: false, cardClass: 'event-card'
        }));
    }
}

import { LightningElement, wire, track } from 'lwc';
import getPublishedEvents from '@salesforce/apex/RegistrationController.getPublishedEvents';
import registerForEvent from '@salesforce/apex/RegistrationController.registerForEvent';

export default class EventRegistration extends LightningElement {
    @track currentStep = 1;
    @track events = [];
    @track selectedEventId = null;
    @track attendeeName = '';
    @track email = '';
    @track phone = '';
    @track company = '';
    @track regAmount = null;
    @track isLoading = false;
    
    // Result
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
                venueName: evt.Venue__r ? `${evt.Venue__r.City__c}, ${evt.Venue__r.State__c}` : 'TBD',
                formattedDate: this.formatDate(evt.Start_Date__c, evt.End_Date__c),
                seatsInfo: `Capacity: ${evt.Max_Capacity__c || 'Unlimited'}`,
                cardClass: this.selectedEventId === evt.Id 
                    ? 'slds-card slds-card_boundary event-card selected' 
                    : 'slds-card slds-card_boundary event-card'
            }));
        } else if (error) {
            console.error('Error loading events:', error);
        }
    }

    formatDate(startDate, endDate) {
        if (!startDate) return 'TBD';
        const start = new Date(startDate);
        const options = { month: 'short', day: 'numeric', year: 'numeric' };
        let result = start.toLocaleDateString('en-US', options);
        if (endDate) {
            const end = new Date(endDate);
            if (start.toDateString() !== end.toDateString()) {
                result += ' - ' + end.toLocaleDateString('en-US', options);
            }
        }
        return result;
    }

    // Step navigation
    get isStep1() { return this.currentStep === 1; }
    get isStep2() { return this.currentStep === 2; }
    get isStep3() { return this.currentStep === 3; }
    
    get isNextDisabled() { return !this.selectedEventId; }
    get isRegisterDisabled() { 
        return !this.attendeeName || !this.email || !this.regAmount || this.isLoading; 
    }
    get isWaitlisted() { return this.resultStatus === 'Waitlisted'; }
    get statusBadgeClass() { 
        return this.resultStatus === 'Confirmed' ? 'slds-theme_success' : 'slds-theme_warning'; 
    }

    handleEventSelect(event) {
        this.selectedEventId = event.currentTarget.dataset.id;
        // Update card styling
        this.events = this.events.map(evt => ({
            ...evt,
            cardClass: this.selectedEventId === evt.Id 
                ? 'slds-card slds-card_boundary event-card selected' 
                : 'slds-card slds-card_boundary event-card'
        }));
    }

    handleNameChange(event) { this.attendeeName = event.target.value; }
    handleEmailChange(event) { this.email = event.target.value; }
    handlePhoneChange(event) { this.phone = event.target.value; }
    handleCompanyChange(event) { this.company = event.target.value; }
    handleAmountChange(event) { this.regAmount = event.target.value; }

    goToStep1() { this.currentStep = 1; }
    goToStep2() { 
        if (this.selectedEventId) {
            this.currentStep = 2; 
        }
    }

    async handleRegister() {
        // Validate
        const allInputs = this.template.querySelectorAll('lightning-input');
        let allValid = true;
        allInputs.forEach(input => {
            if (!input.checkValidity()) {
                input.reportValidity();
                allValid = false;
            }
        });
        
        if (!allValid) return;
        
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
    }
}

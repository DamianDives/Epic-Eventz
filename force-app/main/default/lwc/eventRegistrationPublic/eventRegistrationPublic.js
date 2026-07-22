import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import isGuest from '@salesforce/user/isGuest';
import getPublishedEvents from '@salesforce/apex/RegistrationGuestController.getPublishedEvents';

export default class EventRegistrationPublic extends NavigationMixin(LightningElement) {
    @track events = [];

    get hasEvents() { return this.events && this.events.length > 0; }

    @wire(getPublishedEvents)
    wiredEvents({ data, error }) {
        if (data) {
            this.events = data.map(evt => ({
                ...evt,
                venueName: evt.Venue__r
                    ? `${evt.Venue__r.City__c}, ${evt.Venue__r.State__c}`
                    : 'TBD',
                formattedDate: this.formatDate(evt.Start_Date__c, evt.End_Date__c),
                seatsInfo: evt.Max_Capacity__c ? `${evt.Max_Capacity__c} seats` : 'Unlimited'
            }));
        } else if (error) {
            console.error(error);
        }
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

    handleRegisterClick(event) {
        event.stopPropagation();
        const eventId = event.currentTarget.dataset.id;

        if (isGuest) {
            // Not logged in — redirect to login page with return URL
            const currentUrl = window.location.pathname;
            const loginUrl = currentUrl.replace(/\/s\/.*/, '/s/login');
            window.location.href = loginUrl + '?startURL=' +
                encodeURIComponent(currentUrl + '?eventId=' + eventId);
        } else {
            // Logged in — navigate to registration page or show form
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: {
                    name: 'Register__c'
                },
                state: {
                    eventId: eventId
                }
            });
        }
    }
}

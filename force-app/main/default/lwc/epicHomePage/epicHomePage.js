import { LightningElement, wire, track } from 'lwc';
import getPublishedEvents from '@salesforce/apex/RegistrationGuestController.getPublishedEvents';

export default class EpicHomePage extends LightningElement {
    @track events = [];
    @track currentIndex = 0;

    get hasEvents() { return this.events && this.events.length > 0; }
    get currentEvent() { return this.hasEvents ? this.events[this.currentIndex] : {}; }

    @wire(getPublishedEvents)
    wiredEvents({ data, error }) {
        if (data) {
            this.events = data.map((evt, idx) => ({
                ...evt,
                venueName: evt.Venue__r
                    ? `${evt.Venue__r.City__c}, ${evt.Venue__r.State__c}` : 'TBD',
                formattedDate: this.formatDate(evt.Start_Date__c, evt.End_Date__c),
                seatsInfo: evt.Max_Capacity__c
                    ? `${evt.Max_Capacity__c} seats left` : 'Unlimited',
                dotClass: idx === 0 ? 'dot active' : 'dot'
            }));
        }
    }

    formatDate(start, end) {
        if (!start) return 'TBD';
        const s = new Date(start);
        const opts = { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' };
        return s.toLocaleDateString('en-US', opts);
    }

    prevEvent() {
        if (this.currentIndex > 0) {
            this.currentIndex--;
        } else {
            this.currentIndex = this.events.length - 1;
        }
        this.updateDots();
    }

    nextEvent() {
        if (this.currentIndex < this.events.length - 1) {
            this.currentIndex++;
        } else {
            this.currentIndex = 0;
        }
        this.updateDots();
    }

    goToEvent(event) {
        this.currentIndex = parseInt(event.currentTarget.dataset.index, 10);
        this.updateDots();
    }

    updateDots() {
        this.events = this.events.map((evt, idx) => ({
            ...evt,
            dotClass: idx === this.currentIndex ? 'dot active' : 'dot'
        }));
    }

    handleViewEvent() {
        // Redirect to login page — user must login to register
        const basePath = window.location.pathname.replace(/\/s\/.*/, '/s/');
        const eventId = this.currentEvent.Id;
        window.location.href = basePath + 'login?startURL=' +
            encodeURIComponent(basePath + '?eventId=' + eventId);
    }

    goToLogin() {
        const basePath = window.location.pathname.replace(/\/s\/.*/, '/s/');
        window.location.href = basePath + 'login';
    }

    scrollToEvents() {
        const el = this.template.querySelector('[data-id="events-section"]');
        if (el) el.scrollIntoView({ behavior: 'smooth' });
    }
}

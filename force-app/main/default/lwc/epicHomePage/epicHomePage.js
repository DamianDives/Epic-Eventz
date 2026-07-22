import { LightningElement, wire, track } from 'lwc';
import getPublishedEvents from '@salesforce/apex/RegistrationGuestController.getPublishedEvents';

export default class EpicHomePage extends LightningElement {
    @track allEvents = [];
    @track activeFilter = 'All';

    get eventCount() { return this.allEvents.length; }
    get heroPreview() { return this.allEvents.length > 0 ? this.allEvents[0] : null; }

    get typeFilters() {
        const types = ['All', ...new Set(this.allEvents.map(e => e.Event_Type__c).filter(Boolean))];
        return types.map(t => ({
            value: t,
            label: t,
            chipClass: t === this.activeFilter ? 'chip chip-active' : 'chip'
        }));
    }

    get filteredEvents() {
        if (this.activeFilter === 'All') return this.allEvents;
        return this.allEvents.filter(e => e.Event_Type__c === this.activeFilter);
    }
    get hasFilteredEvents() { return this.filteredEvents.length > 0; }

    @wire(getPublishedEvents)
    wiredEvents({ data, error }) {
        if (data) {
            this.allEvents = data.map(evt => ({
                ...evt,
                venueName: evt.Venue__r
                    ? `${evt.Venue__r.City__c}, ${evt.Venue__r.State__c}` : 'Location TBD',
                formattedDate: this.formatDate(evt.Start_Date__c),
                seatsInfo: evt.Max_Capacity__c ? `${evt.Max_Capacity__c} spots` : 'Open'
            }));
        } else if (error) {
            console.error(error);
        }
    }

    formatDate(start) {
        if (!start) return 'Date TBD';
        const d = new Date(start);
        return d.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' });
    }

    handleFilterClick(event) {
        this.activeFilter = event.currentTarget.dataset.value;
    }

    handleEventTileClick(event) {
        const eventId = event.currentTarget.dataset.id;
        const basePath = window.location.pathname.replace(/\/s\/.*/, '/s/');
        window.location.href = basePath + 'login?startURL=' +
            encodeURIComponent(basePath + '?eventId=' + eventId);
    }

    goToLogin() {
        const basePath = window.location.pathname.replace(/\/s\/.*/, '/s/');
        window.location.href = basePath + 'login';
    }

    scrollToEvents() {
        const el = this.template.querySelector('[data-id="events-anchor"]');
        if (el) el.scrollIntoView({ behavior: 'smooth' });
    }

    scrollToAbout() {
        const el = this.template.querySelector('[data-id="about-anchor"]');
        if (el) el.scrollIntoView({ behavior: 'smooth' });
    }
}

public with sharing class EventTriggerHandler {

    private static final String DOUBLE_BOOKING_ERROR = 'This venue is already booked for the selected dates. Please choose different dates or a different venue.';

    public void handleBeforeInsert(List<Event__c> newEvents) {
        preventVenueDoubleBooking(newEvents, null);
    }

    public void handleBeforeUpdate(List<Event__c> newEvents, Map<Id, Event__c> oldMap) {
        preventVenueDoubleBooking(newEvents, oldMap);
    }

    private void preventVenueDoubleBooking(List<Event__c> events, Map<Id, Event__c> oldMap) {
        // Collect events that need venue overlap checking
        List<Event__c> eventsToCheck = new List<Event__c>();
        Set<Id> venueIds = new Set<Id>();
        Set<Id> currentEventIds = new Set<Id>();

        for (Event__c evt : events) {
            if (evt.Venue__c != null && evt.Start_Date__c != null && evt.End_Date__c != null) {
                // For updates, only check if venue or dates changed
                if (oldMap != null) {
                    Event__c oldEvt = oldMap.get(evt.Id);
                    if (oldEvt.Venue__c == evt.Venue__c &&
                        oldEvt.Start_Date__c == evt.Start_Date__c &&
                        oldEvt.End_Date__c == evt.End_Date__c) {
                        continue; // No relevant change, skip
                    }
                }
                eventsToCheck.add(evt);
                venueIds.add(evt.Venue__c);
                if (evt.Id != null) {
                    currentEventIds.add(evt.Id);
                }
            }
        }

        if (eventsToCheck.isEmpty()) {
            return;
        }

        // Single bulkified query to get all potentially overlapping events at these venues
        List<Event__c> existingEvents = [
            SELECT Id, Venue__c, Start_Date__c, End_Date__c
            FROM Event__c
            WHERE Venue__c IN :venueIds
              AND Id NOT IN :currentEventIds
              AND Start_Date__c != null
              AND End_Date__c != null
        ];

        // Build a map of Venue Id -> list of existing events at that venue
        Map<Id, List<Event__c>> venueToEvents = new Map<Id, List<Event__c>>();
        for (Event__c existing : existingEvents) {
            if (!venueToEvents.containsKey(existing.Venue__c)) {
                venueToEvents.put(existing.Venue__c, new List<Event__c>());
            }
            venueToEvents.get(existing.Venue__c).add(existing);
        }

        // Also check for overlaps among the trigger batch itself (same venue, different records)
        // Build map of venue -> events in current batch
        Map<Id, List<Event__c>> venueToBatchEvents = new Map<Id, List<Event__c>>();
        for (Event__c evt : eventsToCheck) {
            if (!venueToBatchEvents.containsKey(evt.Venue__c)) {
                venueToBatchEvents.put(evt.Venue__c, new List<Event__c>());
            }
            venueToBatchEvents.get(evt.Venue__c).add(evt);
        }

        // Check each event for overlaps
        for (Event__c evt : eventsToCheck) {
            Boolean hasOverlap = false;

            // Check against existing records in database
            List<Event__c> existingAtVenue = venueToEvents.get(evt.Venue__c);
            if (existingAtVenue != null) {
                for (Event__c existing : existingAtVenue) {
                    if (datesOverlap(evt.Start_Date__c, evt.End_Date__c, existing.Start_Date__c, existing.End_Date__c)) {
                        hasOverlap = true;
                        break;
                    }
                }
            }

            // Check against other events in the same batch (for bulk inserts)
            if (!hasOverlap) {
                List<Event__c> batchAtVenue = venueToBatchEvents.get(evt.Venue__c);
                if (batchAtVenue != null) {
                    for (Event__c batchEvt : batchAtVenue) {
                        // Don't compare with itself (use reference equality for new records)
                        if (batchEvt === evt) {
                            continue;
                        }
                        if (datesOverlap(evt.Start_Date__c, evt.End_Date__c, batchEvt.Start_Date__c, batchEvt.End_Date__c)) {
                            hasOverlap = true;
                            break;
                        }
                    }
                }
            }

            if (hasOverlap) {
                evt.addError(DOUBLE_BOOKING_ERROR);
            }
        }
    }

    private Boolean datesOverlap(DateTime start1, DateTime end1, DateTime start2, DateTime end2) {
        // Two events overlap if: Event1.Start < Event2.End AND Event1.End > Event2.Start
        return (start1 < end2 && end1 > start2);
    }
}

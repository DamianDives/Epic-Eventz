@isTest
private class EventTriggerHandlerTest {

    @TestSetup
    static void setupTestData() {
        Venue__c venue = new Venue__c(
            Capacity__c = 500,
            Country__c = 'United States',
            State__c = 'California',
            City__c = 'San Francisco',
            Venue_Type__c = 'Indoor',
            Address__c = '123 Test Blvd',
            Active__c = true
        );
        insert venue;

        Venue__c venue2 = new Venue__c(
            Capacity__c = 300,
            Country__c = 'United States',
            State__c = 'New York',
            City__c = 'New York City',
            Venue_Type__c = 'Indoor',
            Address__c = '456 Test Ave',
            Active__c = true
        );
        insert venue2;
    }

    @isTest
    static void testInsertEventAtVenue_ShouldSucceed() {
        Venue__c venue = [SELECT Id FROM Venue__c WHERE City__c = 'San Francisco' LIMIT 1];

        Event__c evt = new Event__c(
            Name = 'Test Event 1',
            Event_Type__c = 'Conference',
            Event_Status__c = 'Draft',
            Start_Date__c = DateTime.newInstance(2025, 6, 1, 9, 0, 0),
            End_Date__c = DateTime.newInstance(2025, 6, 3, 18, 0, 0),
            Budget__c = 10000,
            Max_Capacity__c = 200,
            Venue__c = venue.Id
        );

        Test.startTest();
        Database.SaveResult sr = Database.insert(evt, false);
        Test.stopTest();

        System.assert(sr.isSuccess(), 'Event insert should succeed when no overlap exists');
    }

    @isTest
    static void testInsertOverlappingEvent_ShouldFail() {
        Venue__c venue = [SELECT Id FROM Venue__c WHERE City__c = 'San Francisco' LIMIT 1];

        // Insert first event
        Event__c evt1 = new Event__c(
            Name = 'First Event',
            Event_Type__c = 'Conference',
            Event_Status__c = 'Draft',
            Start_Date__c = DateTime.newInstance(2025, 7, 1, 9, 0, 0),
            End_Date__c = DateTime.newInstance(2025, 7, 5, 18, 0, 0),
            Budget__c = 10000,
            Max_Capacity__c = 200,
            Venue__c = venue.Id
        );
        insert evt1;

        // Insert second event with overlapping dates at same venue
        Event__c evt2 = new Event__c(
            Name = 'Overlapping Event',
            Event_Type__c = 'Workshop',
            Event_Status__c = 'Draft',
            Start_Date__c = DateTime.newInstance(2025, 7, 3, 9, 0, 0),
            End_Date__c = DateTime.newInstance(2025, 7, 7, 18, 0, 0),
            Budget__c = 5000,
            Max_Capacity__c = 100,
            Venue__c = venue.Id
        );

        Test.startTest();
        Database.SaveResult sr = Database.insert(evt2, false);
        Test.stopTest();

        System.assert(!sr.isSuccess(), 'Overlapping event insert should fail');
        System.assert(
            sr.getErrors()[0].getMessage().contains('This venue is already booked for the selected dates'),
            'Error message should mention venue booking conflict'
        );
    }

    @isTest
    static void testInsertNonOverlappingEvent_ShouldSucceed() {
        Venue__c venue = [SELECT Id FROM Venue__c WHERE City__c = 'San Francisco' LIMIT 1];

        // Insert first event
        Event__c evt1 = new Event__c(
            Name = 'First Event',
            Event_Type__c = 'Conference',
            Event_Status__c = 'Draft',
            Start_Date__c = DateTime.newInstance(2025, 8, 1, 9, 0, 0),
            End_Date__c = DateTime.newInstance(2025, 8, 3, 18, 0, 0),
            Budget__c = 10000,
            Max_Capacity__c = 200,
            Venue__c = venue.Id
        );
        insert evt1;

        // Insert second event with NON-overlapping dates at same venue
        Event__c evt2 = new Event__c(
            Name = 'Non-Overlapping Event',
            Event_Type__c = 'Workshop',
            Event_Status__c = 'Draft',
            Start_Date__c = DateTime.newInstance(2025, 8, 10, 9, 0, 0),
            End_Date__c = DateTime.newInstance(2025, 8, 12, 18, 0, 0),
            Budget__c = 5000,
            Max_Capacity__c = 100,
            Venue__c = venue.Id
        );

        Test.startTest();
        Database.SaveResult sr = Database.insert(evt2, false);
        Test.stopTest();

        System.assert(sr.isSuccess(), 'Non-overlapping event insert should succeed');
    }

    @isTest
    static void testUpdateEventToOverlap_ShouldFail() {
        Venue__c venue = [SELECT Id FROM Venue__c WHERE City__c = 'San Francisco' LIMIT 1];

        // Insert two non-overlapping events
        Event__c evt1 = new Event__c(
            Name = 'Event A',
            Event_Type__c = 'Conference',
            Event_Status__c = 'Draft',
            Start_Date__c = DateTime.newInstance(2025, 9, 1, 9, 0, 0),
            End_Date__c = DateTime.newInstance(2025, 9, 5, 18, 0, 0),
            Budget__c = 10000,
            Max_Capacity__c = 200,
            Venue__c = venue.Id
        );
        Event__c evt2 = new Event__c(
            Name = 'Event B',
            Event_Type__c = 'Workshop',
            Event_Status__c = 'Draft',
            Start_Date__c = DateTime.newInstance(2025, 9, 10, 9, 0, 0),
            End_Date__c = DateTime.newInstance(2025, 9, 12, 18, 0, 0),
            Budget__c = 5000,
            Max_Capacity__c = 100,
            Venue__c = venue.Id
        );
        insert new List<Event__c>{evt1, evt2};

        // Update Event B to overlap with Event A
        evt2.Start_Date__c = DateTime.newInstance(2025, 9, 3, 9, 0, 0);
        evt2.End_Date__c = DateTime.newInstance(2025, 9, 7, 18, 0, 0);

        Test.startTest();
        Database.SaveResult sr = Database.update(evt2, false);
        Test.stopTest();

        System.assert(!sr.isSuccess(), 'Update causing overlap should fail');
        System.assert(
            sr.getErrors()[0].getMessage().contains('This venue is already booked for the selected dates'),
            'Error message should mention venue booking conflict'
        );
    }

    @isTest
    static void testBulkInsert_MixedOverlaps() {
        Venue__c venue = [SELECT Id FROM Venue__c WHERE City__c = 'San Francisco' LIMIT 1];
        Venue__c venue2 = [SELECT Id FROM Venue__c WHERE City__c = 'New York City' LIMIT 1];

        // Insert a baseline event at venue 1
        Event__c baseline = new Event__c(
            Name = 'Baseline Event',
            Event_Type__c = 'Conference',
            Event_Status__c = 'Draft',
            Start_Date__c = DateTime.newInstance(2025, 10, 1, 9, 0, 0),
            End_Date__c = DateTime.newInstance(2025, 10, 5, 18, 0, 0),
            Budget__c = 10000,
            Max_Capacity__c = 200,
            Venue__c = venue.Id
        );
        insert baseline;

        // Bulk insert: some overlap with baseline, some don't, some at different venue
        List<Event__c> bulkEvents = new List<Event__c>();

        // This overlaps with baseline at venue 1 - should fail
        bulkEvents.add(new Event__c(
            Name = 'Bulk Overlap 1',
            Event_Type__c = 'Workshop',
            Event_Status__c = 'Draft',
            Start_Date__c = DateTime.newInstance(2025, 10, 3, 9, 0, 0),
            End_Date__c = DateTime.newInstance(2025, 10, 7, 18, 0, 0),
            Budget__c = 5000,
            Max_Capacity__c = 100,
            Venue__c = venue.Id
        ));

        // This does NOT overlap with baseline at venue 1 - should succeed
        bulkEvents.add(new Event__c(
            Name = 'Bulk No Overlap',
            Event_Type__c = 'Seminar',
            Event_Status__c = 'Draft',
            Start_Date__c = DateTime.newInstance(2025, 10, 10, 9, 0, 0),
            End_Date__c = DateTime.newInstance(2025, 10, 12, 18, 0, 0),
            Budget__c = 8000,
            Max_Capacity__c = 150,
            Venue__c = venue.Id
        ));

        // This is at a different venue - should succeed
        bulkEvents.add(new Event__c(
            Name = 'Bulk Different Venue',
            Event_Type__c = 'Conference',
            Event_Status__c = 'Draft',
            Start_Date__c = DateTime.newInstance(2025, 10, 3, 9, 0, 0),
            End_Date__c = DateTime.newInstance(2025, 10, 7, 18, 0, 0),
            Budget__c = 12000,
            Max_Capacity__c = 250,
            Venue__c = venue2.Id
        ));

        Test.startTest();
        List<Database.SaveResult> results = Database.insert(bulkEvents, false);
        Test.stopTest();

        // First event (overlap) should fail
        System.assert(!results[0].isSuccess(), 'Overlapping bulk event should fail');
        // Second event (no overlap) should succeed
        System.assert(results[1].isSuccess(), 'Non-overlapping bulk event should succeed');
        // Third event (different venue) should succeed
        System.assert(results[2].isSuccess(), 'Event at different venue should succeed');
    }
}

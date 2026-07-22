@isTest
private class RegistrationControllerTest {

    @TestSetup
    static void setup() {
        Venue__c venue = new Venue__c(
            Capacity__c = 100,
            Country__c = 'US',
            State__c = 'CA',
            City__c = 'SF',
            Venue_Type__c = 'Indoor',
            Address__c = '123 Test',
            Active__c = true
        );
        insert venue;
        
        Event__c evt = new Event__c(
            Name = 'Test Published Event',
            Event_Type__c = 'Conference',
            Event_Status__c = 'Published',
            Start_Date__c = DateTime.newInstance(2025, 12, 1, 9, 0, 0),
            End_Date__c = DateTime.newInstance(2025, 12, 3, 18, 0, 0),
            Budget__c = 10000,
            Max_Capacity__c = 2,
            Venue__c = venue.Id
        );
        insert evt;
    }

    @isTest
    static void testGetPublishedEvents() {
        Test.startTest();
        List<Event__c> events = RegistrationController.getPublishedEvents();
        Test.stopTest();
        
        System.assert(!events.isEmpty(), 'Should return published events');
        System.assertEquals('Published', events[0].Event_Status__c);
    }

    @isTest
    static void testRegisterForEvent_NewAttendee_Confirmed() {
        Event__c evt = [SELECT Id FROM Event__c LIMIT 1];
        
        Test.startTest();
        RegistrationController.RegistrationResult result = RegistrationController.registerForEvent(
            evt.Id, 'New Person', 'new@test.com', '555-1234', 'TestCo', 100.00
        );
        Test.stopTest();
        
        System.assertEquals(true, result.success);
        System.assertEquals('Confirmed', result.status);
        System.assertNotEquals(null, result.registrationId);
    }

    @isTest
    static void testRegisterForEvent_ExistingAttendee() {
        Event__c evt = [SELECT Id FROM Event__c LIMIT 1];
        Attendee__c att = new Attendee__c(Name = 'Existing', Email__c = 'existing@test.com');
        insert att;
        
        Test.startTest();
        RegistrationController.RegistrationResult result = RegistrationController.registerForEvent(
            evt.Id, 'Existing', 'existing@test.com', '', '', 100.00
        );
        Test.stopTest();
        
        System.assertEquals(true, result.success);
        // Verify no duplicate attendee created
        System.assertEquals(1, [SELECT COUNT() FROM Attendee__c WHERE Email__c = 'existing@test.com']);
    }

    @isTest
    static void testRegisterForEvent_Waitlisted() {
        Event__c evt = [SELECT Id FROM Event__c LIMIT 1]; // Max capacity = 2
        
        // Fill capacity
        Attendee__c a1 = new Attendee__c(Name = 'A1', Email__c = 'a1@test.com');
        Attendee__c a2 = new Attendee__c(Name = 'A2', Email__c = 'a2@test.com');
        insert new List<Attendee__c>{a1, a2};
        
        insert new List<Registration__c>{
            new Registration__c(Event__c = evt.Id, Attendee__c = a1.Id, Reg_Date__c = Date.today(), Status__c = 'Confirmed', Reg_Amount__c = 100),
            new Registration__c(Event__c = evt.Id, Attendee__c = a2.Id, Reg_Date__c = Date.today(), Status__c = 'Confirmed', Reg_Amount__c = 100)
        };
        
        Test.startTest();
        RegistrationController.RegistrationResult result = RegistrationController.registerForEvent(
            evt.Id, 'Wait Person', 'wait@test.com', '', '', 100.00
        );
        Test.stopTest();
        
        System.assertEquals(true, result.success);
        System.assertEquals('Waitlisted', result.status);
        System.assertEquals(1, result.waitlistPosition);
    }
}

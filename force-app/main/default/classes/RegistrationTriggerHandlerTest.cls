@isTest
private class RegistrationTriggerHandlerTest {

    @TestSetup
    static void setupTestData() {
        Venue__c venue = new Venue__c(
            Capacity__c = 100,
            Country__c = 'United States',
            State__c = 'California',
            City__c = 'Test City',
            Venue_Type__c = 'Indoor',
            Address__c = '123 Test St',
            Active__c = true
        );
        insert venue;
        
        Event__c evt = new Event__c(
            Name = 'Capacity Test Event',
            Event_Type__c = 'Conference',
            Event_Status__c = 'Published',
            Start_Date__c = DateTime.newInstance(2025, 12, 1, 9, 0, 0),
            End_Date__c = DateTime.newInstance(2025, 12, 3, 18, 0, 0),
            Budget__c = 10000,
            Max_Capacity__c = 3,
            Venue__c = venue.Id
        );
        insert evt;
    }

    @isTest
    static void testSingleInsert_UnderCapacity_ShouldConfirm() {
        Event__c evt = [SELECT Id FROM Event__c LIMIT 1];
        Attendee__c att = new Attendee__c(Name = 'Test Person', Email__c = 'test1@test.com');
        insert att;
        
        Registration__c reg = new Registration__c(
            Event__c = evt.Id,
            Attendee__c = att.Id,
            Reg_Date__c = Date.today(),
            Status__c = 'Registered',
            Reg_Amount__c = 100
        );
        
        Test.startTest();
        insert reg;
        Test.stopTest();
        
        reg = [SELECT Status__c, Waitlist_Position__c FROM Registration__c WHERE Id = :reg.Id];
        System.assertEquals('Confirmed', reg.Status__c, 'Should be confirmed when under capacity');
        System.assertEquals(null, reg.Waitlist_Position__c, 'Should have no waitlist position');
    }

    @isTest
    static void testInsert_AtCapacity_ShouldWaitlist() {
        Event__c evt = [SELECT Id FROM Event__c LIMIT 1];
        
        // Create 4 attendees
        List<Attendee__c> attendees = new List<Attendee__c>();
        for (Integer i = 0; i < 4; i++) {
            attendees.add(new Attendee__c(Name = 'Person ' + i, Email__c = 'cap' + i + '@test.com'));
        }
        insert attendees;
        
        // Fill to capacity (Max_Capacity = 3)
        List<Registration__c> regs = new List<Registration__c>();
        for (Integer i = 0; i < 3; i++) {
            regs.add(new Registration__c(
                Event__c = evt.Id, Attendee__c = attendees[i].Id,
                Reg_Date__c = Date.today(), Status__c = 'Registered', Reg_Amount__c = 100
            ));
        }
        insert regs;
        
        // Now insert one more - should be waitlisted
        Registration__c waitlistReg = new Registration__c(
            Event__c = evt.Id, Attendee__c = attendees[3].Id,
            Reg_Date__c = Date.today(), Status__c = 'Registered', Reg_Amount__c = 100
        );
        
        Test.startTest();
        insert waitlistReg;
        Test.stopTest();
        
        waitlistReg = [SELECT Status__c, Waitlist_Position__c FROM Registration__c WHERE Id = :waitlistReg.Id];
        System.assertEquals('Waitlisted', waitlistReg.Status__c, 'Should be waitlisted when at capacity');
        System.assertEquals(1, waitlistReg.Waitlist_Position__c, 'Should be position 1 on waitlist');
    }

    @isTest
    static void testBulkInsert_MixedCapacity() {
        Event__c evt = [SELECT Id FROM Event__c LIMIT 1]; // Max capacity = 3
        
        // Create 5 attendees
        List<Attendee__c> attendees = new List<Attendee__c>();
        for (Integer i = 0; i < 5; i++) {
            attendees.add(new Attendee__c(Name = 'Bulk ' + i, Email__c = 'bulk' + i + '@test.com'));
        }
        insert attendees;
        
        // Insert 5 registrations - first 3 should confirm, last 2 should waitlist
        List<Registration__c> regs = new List<Registration__c>();
        for (Integer i = 0; i < 5; i++) {
            regs.add(new Registration__c(
                Event__c = evt.Id, Attendee__c = attendees[i].Id,
                Reg_Date__c = Date.today(), Status__c = 'Registered', Reg_Amount__c = 100
            ));
        }
        
        Test.startTest();
        insert regs;
        Test.stopTest();
        
        List<Registration__c> inserted = [
            SELECT Status__c, Waitlist_Position__c 
            FROM Registration__c 
            WHERE Attendee__r.Email__c LIKE 'bulk%'
            ORDER BY CreatedDate
        ];
        
        Integer confirmed = 0;
        Integer waitlisted = 0;
        for (Registration__c r : inserted) {
            if (r.Status__c == 'Confirmed') confirmed++;
            if (r.Status__c == 'Waitlisted') waitlisted++;
        }
        System.assertEquals(3, confirmed, 'Should have 3 confirmed');
        System.assertEquals(2, waitlisted, 'Should have 2 waitlisted');
    }

    @isTest
    static void testWaitlistPromotion_CancelConfirmed() {
        Event__c evt = [SELECT Id FROM Event__c LIMIT 1]; // Max capacity = 3
        
        List<Attendee__c> attendees = new List<Attendee__c>();
        for (Integer i = 0; i < 4; i++) {
            attendees.add(new Attendee__c(Name = 'Promo ' + i, Email__c = 'promo' + i + '@test.com'));
        }
        insert attendees;
        
        // Fill capacity + 1 waitlisted
        List<Registration__c> regs = new List<Registration__c>();
        for (Integer i = 0; i < 4; i++) {
            regs.add(new Registration__c(
                Event__c = evt.Id, Attendee__c = attendees[i].Id,
                Reg_Date__c = Date.today(), Status__c = 'Registered', Reg_Amount__c = 100
            ));
        }
        insert regs;
        
        // Verify setup - 3 confirmed, 1 waitlisted
        List<Registration__c> confirmed = [SELECT Id FROM Registration__c WHERE Status__c = 'Confirmed' AND Event__c = :evt.Id];
        System.assertEquals(3, confirmed.size(), 'Should have 3 confirmed initially');
        
        // Cancel one confirmed registration
        Registration__c toCancel = [SELECT Id, Status__c FROM Registration__c WHERE Status__c = 'Confirmed' AND Event__c = :evt.Id LIMIT 1];
        toCancel.Status__c = 'Cancelled';
        
        Test.startTest();
        update toCancel;
        Test.stopTest();
        
        // The waitlisted one should now be promoted (via Queueable)
        List<Registration__c> nowConfirmed = [SELECT Id FROM Registration__c WHERE Status__c = 'Confirmed' AND Event__c = :evt.Id];
        System.assertEquals(3, nowConfirmed.size(), 'Should still have 3 confirmed after promotion');
    }

    @isTest
    static void testWaitlistSequencing() {
        Event__c evt = [SELECT Id FROM Event__c LIMIT 1]; // Max capacity = 3
        
        // Fill capacity first
        List<Attendee__c> fillers = new List<Attendee__c>();
        for (Integer i = 0; i < 3; i++) {
            fillers.add(new Attendee__c(Name = 'Filler ' + i, Email__c = 'filler' + i + '@test.com'));
        }
        insert fillers;
        
        List<Registration__c> fillerRegs = new List<Registration__c>();
        for (Integer i = 0; i < 3; i++) {
            fillerRegs.add(new Registration__c(
                Event__c = evt.Id, Attendee__c = fillers[i].Id,
                Reg_Date__c = Date.today(), Status__c = 'Registered', Reg_Amount__c = 100
            ));
        }
        insert fillerRegs;
        
        // Now add waitlisted ones sequentially
        Attendee__c w1 = new Attendee__c(Name = 'Wait 1', Email__c = 'wait1@test.com');
        Attendee__c w2 = new Attendee__c(Name = 'Wait 2', Email__c = 'wait2@test.com');
        insert new List<Attendee__c>{w1, w2};
        
        Registration__c wr1 = new Registration__c(Event__c = evt.Id, Attendee__c = w1.Id, Reg_Date__c = Date.today(), Status__c = 'Registered', Reg_Amount__c = 100);
        insert wr1;
        
        Registration__c wr2 = new Registration__c(Event__c = evt.Id, Attendee__c = w2.Id, Reg_Date__c = Date.today(), Status__c = 'Registered', Reg_Amount__c = 100);
        
        Test.startTest();
        insert wr2;
        Test.stopTest();
        
        wr1 = [SELECT Waitlist_Position__c FROM Registration__c WHERE Id = :wr1.Id];
        wr2 = [SELECT Waitlist_Position__c FROM Registration__c WHERE Id = :wr2.Id];
        
        System.assertEquals(1, wr1.Waitlist_Position__c, 'First waitlisted should be position 1');
        System.assertEquals(2, wr2.Waitlist_Position__c, 'Second waitlisted should be position 2');
    }
}

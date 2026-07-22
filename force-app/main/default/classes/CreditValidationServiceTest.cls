@isTest
private class CreditValidationServiceTest {

    @TestSetup
    static void setup() {
        Venue__c venue = new Venue__c(
            Capacity__c = 500, Country__c = 'US', State__c = 'CA',
            City__c = 'SF', Venue_Type__c = 'Indoor',
            Address__c = '123 Test', Active__c = true
        );
        insert venue;

        Event__c evt = new Event__c(
            Name = 'Credit Test Event', Event_Type__c = 'Conference',
            Event_Status__c = 'Published', Budget__c = 10000,
            Max_Capacity__c = 100, Venue__c = venue.Id,
            Start_Date__c = DateTime.newInstance(2025, 12, 1, 9, 0, 0),
            End_Date__c = DateTime.newInstance(2025, 12, 3, 18, 0, 0)
        );
        insert evt;

        // Attendee with USD preference, $5000 limit
        Attendee__c usdAttendee = new Attendee__c(
            Name = 'USD Person', Email__c = 'usd@test.com',
            Credit_Limit__c = 5000, Preferred_Currency__c = 'USD'
        );
        // Attendee with GBP preference, 4000 GBP limit
        Attendee__c gbpAttendee = new Attendee__c(
            Name = 'GBP Person', Email__c = 'gbp@test.com',
            Credit_Limit__c = 4000, Preferred_Currency__c = 'GBP'
        );
        // Attendee with no limit
        Attendee__c noLimitAttendee = new Attendee__c(
            Name = 'No Limit', Email__c = 'nolimit@test.com',
            Preferred_Currency__c = 'USD'
        );
        insert new List<Attendee__c>{usdAttendee, gbpAttendee, noLimitAttendee};
    }

    @isTest
    static void testValidateCredit_UnderLimit_Passes() {
        Attendee__c att = [SELECT Id FROM Attendee__c WHERE Email__c = 'usd@test.com'];

        Test.startTest();
        CreditValidationService.ValidationResult result =
            CreditValidationService.validateCredit(att.Id, 2000, 'USD');
        Test.stopTest();

        System.assertEquals(true, result.isValid, 'Should pass when under limit');
        System.assert(result.message.contains('passed'), 'Message should say passed');
    }

    @isTest
    static void testValidateCredit_OverLimit_Fails() {
        Attendee__c att = [SELECT Id FROM Attendee__c WHERE Email__c = 'usd@test.com'];

        Test.startTest();
        CreditValidationService.ValidationResult result =
            CreditValidationService.validateCredit(att.Id, 6000, 'USD');
        Test.stopTest();

        System.assertEquals(false, result.isValid, 'Should fail when over limit');
        System.assert(result.message.contains('exceeded'), 'Message should mention exceeded');
    }

    @isTest
    static void testValidateCredit_WithExistingRegistrations() {
        Attendee__c att = [SELECT Id FROM Attendee__c WHERE Email__c = 'usd@test.com'];
        Event__c evt = [SELECT Id FROM Event__c LIMIT 1];

        // Create existing registration of $3000
        Registration__c existing = new Registration__c(
            Event__c = evt.Id, Attendee__c = att.Id,
            Reg_Date__c = Date.today(), Status__c = 'Confirmed',
            Reg_Amount__c = 3000, Payment_Status__c = 'Paid'
        );
        insert existing;

        Test.startTest();
        // Try to add $3000 more (total would be $6000, limit is $5000)
        CreditValidationService.ValidationResult result =
            CreditValidationService.validateCredit(att.Id, 3000, 'USD');
        Test.stopTest();

        System.assertEquals(false, result.isValid, 'Should fail - cumulative exceeds limit');
    }

    @isTest
    static void testValidateCredit_CancelledNotCounted() {
        Attendee__c att = [SELECT Id FROM Attendee__c WHERE Email__c = 'usd@test.com'];
        Event__c evt = [SELECT Id FROM Event__c LIMIT 1];

        // Create cancelled registration
        Registration__c cancelled = new Registration__c(
            Event__c = evt.Id, Attendee__c = att.Id,
            Reg_Date__c = Date.today(), Status__c = 'Cancelled',
            Reg_Amount__c = 4000, Payment_Status__c = 'Refunded'
        );
        insert cancelled;

        Test.startTest();
        // $4500 should pass because the cancelled one doesn't count
        CreditValidationService.ValidationResult result =
            CreditValidationService.validateCredit(att.Id, 4500, 'USD');
        Test.stopTest();

        System.assertEquals(true, result.isValid, 'Cancelled registrations should not count');
    }

    @isTest
    static void testValidateCredit_MultiCurrency_GBP() {
        Attendee__c att = [SELECT Id FROM Attendee__c WHERE Email__c = 'gbp@test.com'];

        // GBP attendee with 4000 GBP limit
        // $5000 USD = 5000 * 1.00 / 1.27 = ~3937 GBP (under limit)
        Test.startTest();
        CreditValidationService.ValidationResult result =
            CreditValidationService.validateCredit(att.Id, 5000, 'USD');
        Test.stopTest();

        System.assertEquals(true, result.isValid, 'Should pass - $5000 converts to ~3937 GBP');
    }

    @isTest
    static void testValidateCredit_MultiCurrency_GBP_OverLimit() {
        Attendee__c att = [SELECT Id FROM Attendee__c WHERE Email__c = 'gbp@test.com'];

        // $6000 USD = 6000 * 1.00 / 1.27 = ~4724 GBP (over 4000 limit)
        Test.startTest();
        CreditValidationService.ValidationResult result =
            CreditValidationService.validateCredit(att.Id, 6000, 'USD');
        Test.stopTest();

        System.assertEquals(false, result.isValid, 'Should fail - $6000 converts to ~4724 GBP');
    }

    @isTest
    static void testValidateCredit_NoLimit_Skips() {
        Attendee__c att = [SELECT Id FROM Attendee__c WHERE Email__c = 'nolimit@test.com'];

        Test.startTest();
        CreditValidationService.ValidationResult result =
            CreditValidationService.validateCredit(att.Id, 999999, 'USD');
        Test.stopTest();

        System.assertEquals(true, result.isValid, 'Should skip validation when no limit');
    }

    @isTest
    static void testConvertCurrency() {
        // USD to GBP: 100 * 1.00 / 1.27 = ~78.74
        Decimal result = CreditValidationService.convertCurrency(100, 'USD', 'GBP');
        System.assert(result > 78 && result < 79, 'USD to GBP conversion should be ~78.74');

        // GBP to USD: 100 * 1.27 / 1.00 = 127
        Decimal result2 = CreditValidationService.convertCurrency(100, 'GBP', 'USD');
        System.assertEquals(127.00, result2, 'GBP to USD should be 127');

        // Same currency
        Decimal result3 = CreditValidationService.convertCurrency(100, 'USD', 'USD');
        System.assertEquals(100, result3, 'Same currency should return same amount');
    }

    @isTest
    static void testTrigger_BlocksOverLimit() {
        Attendee__c att = [SELECT Id FROM Attendee__c WHERE Email__c = 'usd@test.com'];
        Event__c evt = [SELECT Id FROM Event__c LIMIT 1];

        // Try to insert a registration that exceeds credit limit
        Registration__c reg = new Registration__c(
            Event__c = evt.Id, Attendee__c = att.Id,
            Reg_Date__c = Date.today(), Status__c = 'Registered',
            Reg_Amount__c = 6000, Payment_Status__c = 'Pending'
        );

        Test.startTest();
        Database.SaveResult sr = Database.insert(reg, false);
        Test.stopTest();

        System.assertEquals(false, sr.isSuccess(), 'Should block insert when over credit limit');
        System.assert(sr.getErrors()[0].getMessage().contains('exceeded'),
            'Error should mention credit limit exceeded');
    }
}

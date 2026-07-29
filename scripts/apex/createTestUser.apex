// Try creating a community user directly to see the exact error
try {
    // Get the account
    Account acct = [SELECT Id FROM Account WHERE Name = 'EpicEventz Community' LIMIT 1];
    System.debug('Account found: ' + acct.Id);
    
    // Get or create contact
    Contact c;
    List<Contact> contacts = [SELECT Id FROM Contact WHERE Email = 'testuser999@epictest.com' LIMIT 1];
    if (contacts.isEmpty()) {
        c = new Contact(FirstName = 'Test', LastName = 'User999', Email = 'testuser999@epictest.com', AccountId = acct.Id);
        insert c;
        System.debug('Contact created: ' + c.Id);
    } else {
        c = contacts[0];
        System.debug('Contact exists: ' + c.Id);
    }
    
    // Check network
    String networkId = Network.getNetworkId();
    System.debug('Network ID from this context: ' + networkId);
    
    // Try Site.createExternalUser
    User u = new User(
        FirstName = 'Test',
        LastName = 'User999',
        Email = 'testuser999@epictest.com',
        Username = 'testuser999@epictest.com',
        Alias = 'tuser9',
        CommunityNickname = 'testuser999',
        TimeZoneSidKey = 'America/Los_Angeles',
        LocaleSidKey = 'en_US',
        EmailEncodingKey = 'UTF-8',
        LanguageLocaleKey = 'en_US',
        ContactId = c.Id
    );
    
    String userId = Site.createExternalUser(u, acct.Id, 'TestPass123!');
    System.debug('SUCCESS! User created: ' + userId);
    
} catch (Exception e) {
    System.debug('ERROR TYPE: ' + e.getTypeName());
    System.debug('ERROR MSG: ' + e.getMessage());
    System.debug('STACK: ' + e.getStackTraceString());
}

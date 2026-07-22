public without sharing class SelfRegistrationController {
    
    @AuraEnabled
    public static RegistrationResult registerUser(
        String firstName, String lastName, String email, String password
    ) {
        RegistrationResult result = new RegistrationResult();
        
        try {
            // Validate inputs
            if (String.isBlank(firstName) || String.isBlank(lastName) || 
                String.isBlank(email) || String.isBlank(password)) {
                result.success = false;
                result.message = 'All fields are required.';
                return result;
            }
            
            if (password.length() < 8) {
                result.success = false;
                result.message = 'Password must be at least 8 characters.';
                return result;
            }
            
            // Check if user already exists
            List<User> existingUsers = [
                SELECT Id FROM User WHERE Username = :email LIMIT 1
            ];
            if (!existingUsers.isEmpty()) {
                result.success = false;
                result.message = 'An account with this email already exists. Please log in. If you cannot log in, use "Forgot Password".';
                return result;
            }
            
            // Reuse an existing Contact with this email (from a previous failed attempt)
            // instead of creating a duplicate Contact record.
            Contact existingContact = null;
            List<Contact> matches = [
                SELECT Id FROM Contact WHERE Email = :email LIMIT 1
            ];
            if (!matches.isEmpty()) {
                existingContact = matches[0];
            }
            
            // Create the user via Site.createExternalUser
            User u = new User();
            u.FirstName = firstName;
            u.LastName = lastName;
            u.Email = email;
            u.Username = email;
            u.CommunityNickname = firstName + lastName + String.valueOf(Math.random()).substring(2, 6);
            u.Alias = (firstName.substring(0, Math.min(firstName.length(), 4)) + lastName.substring(0, Math.min(lastName.length(), 4))).toLowerCase();
            u.TimeZoneSidKey = 'America/Los_Angeles';
            u.LocaleSidKey = 'en_US';
            u.EmailEncodingKey = 'UTF-8';
            u.LanguageLocaleKey = 'en_US';
            
            // Use Site.createExternalUser for community registration
            // This creates a Contact + User with the site's guest profile
            String accountId = getDefaultAccountId();
            
            if (accountId == null) {
                result.success = false;
                result.message = 'Site configuration error. Contact administrator.';
                return result;
            }
            
            // Create the Attendee__c record FIRST, in its own DML statement,
            // before touching Contact/User (setup objects). Mixing DML on
            // setup objects (User/Contact via Site.createExternalUser) with
            // non-setup custom objects (Attendee__c) in the same transaction
            // throws MIXED_DML_OPERATION, so Attendee__c must be fully
            // committed before we get to the Contact + User creation below.
            List<Attendee__c> existingAttendees = [
                SELECT Id FROM Attendee__c WHERE Email__c = :email LIMIT 1
            ];
            if (existingAttendees.isEmpty()) {
                Attendee__c att = new Attendee__c(
                    Name = firstName + ' ' + lastName,
                    Email__c = email,
                    Preferred_Currency__c = 'USD'
                );
                insert att;
            }
            
            // Now handle Contact + User (setup objects — safe to mix these
            // two together, just not with Attendee__c above).
            Contact c;
            if (existingContact != null) {
                c = existingContact;
            } else {
                c = new Contact(
                    FirstName = firstName,
                    LastName = lastName,
                    Email = email,
                    AccountId = accountId
                );
                insert c;
            }
            
            // Create the community user
            u.ContactId = c.Id;
            String userId = Site.createExternalUser(u, accountId, password);
            
            if (userId != null) {
                result.success = true;
                result.message = 'Account created successfully! You can now log in.';
                result.userId = userId;
            } else {
                result.success = false;
                result.message = 'Unable to create account. Please try again.';
            }
            
        } catch (Site.ExternalUserCreateException e) {
            result.success = false;
            result.message = 'Registration error: ' + e.getMessage();
        } catch (Exception e) {
            result.success = false;
            result.message = 'Error: ' + e.getMessage();
        }
        
        return result;
    }
    
    @AuraEnabled
    public static LoginResult loginUser(String username, String password, String startUrl) {
        LoginResult result = new LoginResult();
        try {
            PageReference pageRef = Site.login(username, password, startUrl);
            if (pageRef != null) {
                result.success = true;
                result.redirectUrl = pageRef.getUrl();
            } else {
                result.success = false;
                result.message = 'Invalid email or password.';
            }
        } catch (Exception e) {
            result.success = false;
            // Surface the real reason (e.g. "user is inactive", "wrong password",
            // "too many failed logins") instead of hiding it behind a generic message.
            result.message = e.getMessage();
        }
        return result;
    }
    
    public class LoginResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String redirectUrl;
        @AuraEnabled public String message;
    }
    
    private static String getDefaultAccountId() {
        List<Account> defaultAcct = [
            SELECT Id FROM Account
            WHERE Name = 'EpicEventz Community' LIMIT 1
        ];
        if (!defaultAcct.isEmpty()) {
            return defaultAcct[0].Id;
        }
        
        // Create it if it doesn't exist yet
        Account a = new Account(Name = 'EpicEventz Community');
        insert a;
        return a.Id;
    }
    
    public class RegistrationResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public String userId;
    }
}

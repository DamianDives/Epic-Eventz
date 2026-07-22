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
                result.message = 'An account with this email already exists. Please log in.';
                return result;
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
            
            // Create Contact first
            Contact c = new Contact(
                FirstName = firstName,
                LastName = lastName,
                Email = email,
                AccountId = accountId
            );
            insert c;
            
            // Also create an Attendee record linked to this contact
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
    public static String loginUser(String username, String password, String startUrl) {
        try {
            ApexPages.PageReference pageRef = Site.login(username, password, startUrl);
            if (pageRef != null) {
                return pageRef.getUrl();
            }
            return null;
        } catch (Exception e) {
            return null;
        }
    }
    
    private static String getDefaultAccountId() {
        // Try to find an existing account for community users
        // First check if there's a site-configured account
        String networkId = Network.getNetworkId();
        if (networkId != null) {
            // Try network-based account
            List<Account> accts = [
                SELECT Id FROM Account 
                WHERE Name = 'EpicEventz Community' LIMIT 1
            ];
            if (!accts.isEmpty()) return accts[0].Id;
        }
        
        // Fallback: create or find default account
        List<Account> defaultAcct = [
            SELECT Id FROM Account 
            WHERE Name = 'EpicEventz Community' LIMIT 1
        ];
        if (!defaultAcct.isEmpty()) {
            return defaultAcct[0].Id;
        }
        
        // Create it
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

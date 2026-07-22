public with sharing class CreditValidationService {
    
    // Currency conversion rates to USD (base currency)
    private static final Map<String, Decimal> CONVERSION_RATES = new Map<String, Decimal>{
        'USD' => 1.00,
        'EUR' => 1.08,
        'GBP' => 1.27,
        'INR' => 0.012,
        'AUD' => 0.65,
        'CAD' => 0.74,
        'JPY' => 0.0067
    };
    
    public class ValidationResult {
        public Boolean isValid;
        public String message;
        public Decimal totalExposure;
        public Decimal creditLimit;
        public Decimal convertedAmount;
        
        public ValidationResult() {
            this.isValid = true;
        }
    }
    
    /**
     * Validates credit for a single registration.
     * Converts the registration amount to the attendee's preferred currency,
     * sums all open (non-cancelled) registration amounts for that attendee,
     * and compares against their credit limit.
     */
    public static ValidationResult validateCredit(Id attendeeId, Decimal regAmount, String regCurrency) {
        ValidationResult result = new ValidationResult();
        
        Attendee__c attendee = [
            SELECT Id, Credit_Limit__c, Preferred_Currency__c 
            FROM Attendee__c WHERE Id = :attendeeId
        ];
        
        if (attendee.Credit_Limit__c == null || attendee.Credit_Limit__c == 0) {
            result.isValid = true;
            result.message = 'No credit limit set — validation skipped.';
            return result;
        }
        
        String preferredCurrency = attendee.Preferred_Currency__c != null 
            ? attendee.Preferred_Currency__c : 'USD';
        
        // Convert registration amount to attendee's preferred currency
        Decimal convertedNewAmount = convertCurrency(regAmount, regCurrency, preferredCurrency);
        result.convertedAmount = convertedNewAmount;
        
        // Sum all existing open registration amounts (converted to preferred currency)
        Decimal existingExposure = getExistingExposure(attendeeId, preferredCurrency);
        
        result.totalExposure = existingExposure + convertedNewAmount;
        result.creditLimit = attendee.Credit_Limit__c;
        
        if (result.totalExposure > attendee.Credit_Limit__c) {
            result.isValid = false;
            result.message = 'Credit limit exceeded. Total exposure: ' + 
                result.totalExposure.setScale(2) + ' ' + preferredCurrency + 
                ' exceeds limit of ' + attendee.Credit_Limit__c.setScale(2) + 
                ' ' + preferredCurrency + '.';
        } else {
            result.isValid = true;
            result.message = 'Credit validation passed.';
        }
        
        return result;
    }
    
    /**
     * Bulk validation for multiple registrations.
     * Returns a map of Registration index -> ValidationResult.
     */
    public static Map<Integer, ValidationResult> validateCreditBulk(
        List<Registration__c> registrations
    ) {
        Map<Integer, ValidationResult> results = new Map<Integer, ValidationResult>();
        
        // Collect attendee IDs
        Set<Id> attendeeIds = new Set<Id>();
        for (Registration__c reg : registrations) {
            if (reg.Attendee__c != null) {
                attendeeIds.add(reg.Attendee__c);
            }
        }
        
        if (attendeeIds.isEmpty()) return results;
        
        // Bulk query attendees
        Map<Id, Attendee__c> attendees = new Map<Id, Attendee__c>([
            SELECT Id, Credit_Limit__c, Preferred_Currency__c 
            FROM Attendee__c WHERE Id IN :attendeeIds
        ]);
        
        // Bulk query existing open registrations per attendee
        Map<Id, List<Registration__c>> existingRegs = new Map<Id, List<Registration__c>>();
        for (Registration__c reg : [
            SELECT Id, Attendee__c, Reg_Amount__c, Converted_Amount__c
            FROM Registration__c
            WHERE Attendee__c IN :attendeeIds
            AND Status__c != 'Cancelled'
        ]) {
            if (!existingRegs.containsKey(reg.Attendee__c)) {
                existingRegs.put(reg.Attendee__c, new List<Registration__c>());
            }
            existingRegs.get(reg.Attendee__c).add(reg);
        }
        
        // Track batch exposure per attendee
        Map<Id, Decimal> batchExposure = new Map<Id, Decimal>();
        
        for (Integer i = 0; i < registrations.size(); i++) {
            Registration__c reg = registrations[i];
            ValidationResult result = new ValidationResult();
            
            if (reg.Attendee__c == null) {
                result.isValid = true;
                result.message = 'No attendee — skipped.';
                results.put(i, result);
                continue;
            }
            
            Attendee__c attendee = attendees.get(reg.Attendee__c);
            if (attendee == null || attendee.Credit_Limit__c == null || attendee.Credit_Limit__c == 0) {
                result.isValid = true;
                result.message = 'No credit limit set — validation skipped.';
                results.put(i, result);
                continue;
            }
            
            String preferredCurrency = attendee.Preferred_Currency__c != null 
                ? attendee.Preferred_Currency__c : 'USD';
            
            // Convert new amount (assume reg amount is in USD if not specified)
            Decimal regAmount = reg.Reg_Amount__c != null ? reg.Reg_Amount__c : 0;
            Decimal convertedNew = convertCurrency(regAmount, 'USD', preferredCurrency);
            result.convertedAmount = convertedNew;
            
            // Calculate existing exposure
            Decimal existingExp = 0;
            List<Registration__c> existing = existingRegs.get(reg.Attendee__c);
            if (existing != null) {
                for (Registration__c existReg : existing) {
                    Decimal amount = existReg.Reg_Amount__c != null ? existReg.Reg_Amount__c : 0;
                    existingExp += convertCurrency(amount, 'USD', preferredCurrency);
                }
            }
            
            // Add batch exposure (from earlier records in this same batch)
            Decimal batchExp = batchExposure.containsKey(reg.Attendee__c) 
                ? batchExposure.get(reg.Attendee__c) : 0;
            
            result.totalExposure = existingExp + batchExp + convertedNew;
            result.creditLimit = attendee.Credit_Limit__c;
            
            if (result.totalExposure > attendee.Credit_Limit__c) {
                result.isValid = false;
                result.message = 'Credit limit exceeded. Total exposure: ' + 
                    result.totalExposure.setScale(2) + ' ' + preferredCurrency + 
                    ' exceeds limit of ' + attendee.Credit_Limit__c.setScale(2) + 
                    ' ' + preferredCurrency + '.';
            } else {
                result.isValid = true;
                result.message = 'Credit validation passed.';
                // Track this amount for subsequent records in the batch
                batchExposure.put(reg.Attendee__c, batchExp + convertedNew);
            }
            
            results.put(i, result);
        }
        
        return results;
    }
    
    /**
     * Gets total existing exposure for an attendee (all non-cancelled registrations).
     */
    private static Decimal getExistingExposure(Id attendeeId, String targetCurrency) {
        Decimal total = 0;
        for (Registration__c reg : [
            SELECT Reg_Amount__c FROM Registration__c
            WHERE Attendee__c = :attendeeId AND Status__c != 'Cancelled'
        ]) {
            Decimal amount = reg.Reg_Amount__c != null ? reg.Reg_Amount__c : 0;
            total += convertCurrency(amount, 'USD', targetCurrency);
        }
        return total;
    }
    
    /**
     * Converts an amount from one currency to another using static rates.
     */
    public static Decimal convertCurrency(Decimal amount, String fromCurrency, String toCurrency) {
        if (fromCurrency == toCurrency) return amount;
        if (amount == null || amount == 0) return 0;
        
        // Convert to USD first (base), then to target
        Decimal fromRate = CONVERSION_RATES.containsKey(fromCurrency) 
            ? CONVERSION_RATES.get(fromCurrency) : 1.00;
        Decimal toRate = CONVERSION_RATES.containsKey(toCurrency) 
            ? CONVERSION_RATES.get(toCurrency) : 1.00;
        
        // amount in source * sourceToUSD rate = USD amount
        // USD amount / targetToUSD rate = target amount
        Decimal usdAmount = amount * fromRate;
        Decimal targetAmount = usdAmount / toRate;
        
        return targetAmount.setScale(2, RoundingMode.HALF_UP);
    }
}

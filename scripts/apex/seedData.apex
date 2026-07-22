// Create Venues
Venue__c v1 = new Venue__c(Capacity__c = 500, Country__c = 'United States', State__c = 'California', City__c = 'San Francisco', Venue_Type__c = 'Indoor', Address__c = '123 Convention Center Blvd', Active__c = true);
Venue__c v2 = new Venue__c(Capacity__c = 200, Country__c = 'United States', State__c = 'New York', City__c = 'New York City', Venue_Type__c = 'Indoor', Address__c = '456 Tech Hub Ave', Active__c = true);
Venue__c v3 = new Venue__c(Capacity__c = 1000, Country__c = 'United Kingdom', State__c = 'England', City__c = 'London', Venue_Type__c = 'Outdoor', Address__c = '789 Hyde Park Lane', Active__c = true);
insert new List<Venue__c>{v1, v2, v3};

// Create Events
Event__c e1 = new Event__c(Name = 'Tech Summit 2025', Event_Type__c = 'Conference', Event_Status__c = 'Published', Start_Date__c = DateTime.newInstance(2025, 9, 15, 9, 0, 0), End_Date__c = DateTime.newInstance(2025, 9, 17, 18, 0, 0), Budget__c = 50000, Max_Capacity__c = 400, Venue__c = v1.Id);
Event__c e2 = new Event__c(Name = 'AI Workshop', Event_Type__c = 'Workshop', Event_Status__c = 'Draft', Start_Date__c = DateTime.newInstance(2025, 10, 5, 10, 0, 0), End_Date__c = DateTime.newInstance(2025, 10, 5, 17, 0, 0), Budget__c = 15000, Max_Capacity__c = 150, Venue__c = v2.Id);
Event__c e3 = new Event__c(Name = 'Cloud Computing Seminar', Event_Type__c = 'Seminar', Event_Status__c = 'Published', Start_Date__c = DateTime.newInstance(2025, 11, 1, 9, 0, 0), End_Date__c = DateTime.newInstance(2025, 11, 2, 17, 0, 0), Budget__c = 30000, Max_Capacity__c = 800, Venue__c = v3.Id);
Event__c e4 = new Event__c(Name = 'DevOps Meetup', Event_Type__c = 'Meetup', Event_Status__c = 'Published', Start_Date__c = DateTime.newInstance(2025, 12, 10, 18, 0, 0), End_Date__c = DateTime.newInstance(2025, 12, 10, 21, 0, 0), Budget__c = 5000, Max_Capacity__c = 100, Venue__c = v2.Id);
Event__c e5 = new Event__c(Name = 'Web Development Bootcamp', Event_Type__c = 'Workshop', Event_Status__c = 'Draft', Start_Date__c = DateTime.newInstance(2026, 1, 20, 9, 0, 0), End_Date__c = DateTime.newInstance(2026, 1, 24, 17, 0, 0), Budget__c = 25000, Max_Capacity__c = 300, Venue__c = v1.Id);
insert new List<Event__c>{e1, e2, e3, e4, e5};

// Create Attendees
List<Attendee__c> attendees = new List<Attendee__c>();
attendees.add(new Attendee__c(Name = 'John Smith', Email__c = 'john.smith@techcorp.com', Phone__c = '555-0101', Company__c = 'TechCorp', Country__c = 'United States', Credit_Limit__c = 5000, Preferred_Currency__c = 'USD', VIP_Status__c = true));
attendees.add(new Attendee__c(Name = 'Sarah Johnson', Email__c = 'sarah.j@innovate.io', Phone__c = '555-0102', Company__c = 'Innovate IO', Country__c = 'United States', Credit_Limit__c = 3000, Preferred_Currency__c = 'USD', VIP_Status__c = false));
attendees.add(new Attendee__c(Name = 'James Wilson', Email__c = 'j.wilson@dataflow.co.uk', Phone__c = '+44-20-7946-0958', Company__c = 'DataFlow Ltd', Country__c = 'United Kingdom', Credit_Limit__c = 4000, Preferred_Currency__c = 'GBP', VIP_Status__c = true));
attendees.add(new Attendee__c(Name = 'Priya Patel', Email__c = 'priya.patel@cloudnine.in', Phone__c = '+91-98765-43210', Company__c = 'CloudNine Solutions', Country__c = 'India', Credit_Limit__c = 2500, Preferred_Currency__c = 'INR', VIP_Status__c = false));
attendees.add(new Attendee__c(Name = 'Michael Chen', Email__c = 'mchen@quantum.dev', Phone__c = '555-0105', Company__c = 'Quantum Dev', Country__c = 'United States', Credit_Limit__c = 6000, Preferred_Currency__c = 'USD', VIP_Status__c = true));
attendees.add(new Attendee__c(Name = 'Emma Rodriguez', Email__c = 'emma.r@startuplab.com', Phone__c = '555-0106', Company__c = 'StartupLab', Country__c = 'United States', Credit_Limit__c = 2000, Preferred_Currency__c = 'USD', VIP_Status__c = false));
attendees.add(new Attendee__c(Name = 'Kenji Tanaka', Email__c = 'kenji@tokyotech.jp', Phone__c = '+81-3-1234-5678', Company__c = 'Tokyo Tech Inc', Country__c = 'Japan', Credit_Limit__c = 3500, Preferred_Currency__c = 'JPY', VIP_Status__c = false));
attendees.add(new Attendee__c(Name = 'Lisa Anderson', Email__c = 'lisa.a@globalsoft.com', Phone__c = '555-0108', Company__c = 'GlobalSoft', Country__c = 'United States', Credit_Limit__c = 4500, Preferred_Currency__c = 'USD', VIP_Status__c = true));
attendees.add(new Attendee__c(Name = 'Raj Krishnamurthy', Email__c = 'raj.k@infosys.co.in', Phone__c = '+91-80-2345-6789', Company__c = 'InfoSys', Country__c = 'India', Credit_Limit__c = 3000, Preferred_Currency__c = 'INR', VIP_Status__c = false));
attendees.add(new Attendee__c(Name = 'Sophie Martin', Email__c = 'sophie.m@eurotechfr.eu', Phone__c = '+33-1-2345-6789', Company__c = 'EuroTech France', Country__c = 'France', Credit_Limit__c = 3500, Preferred_Currency__c = 'EUR', VIP_Status__c = false));
attendees.add(new Attendee__c(Name = 'David O\'Brien', Email__c = 'david.ob@aussiedev.com.au', Phone__c = '+61-2-9876-5432', Company__c = 'AussieDev', Country__c = 'Australia', Credit_Limit__c = 4000, Preferred_Currency__c = 'AUD', VIP_Status__c = true));
attendees.add(new Attendee__c(Name = 'Maria Garcia', Email__c = 'maria.g@techlatam.mx', Phone__c = '+52-55-1234-5678', Company__c = 'TechLatam', Country__c = 'Mexico', Credit_Limit__c = 2500, Preferred_Currency__c = 'USD', VIP_Status__c = false));
insert attendees;

// Create some Registrations linking Events and Attendees
List<Registration__c> regs = new List<Registration__c>();
regs.add(new Registration__c(Event__c = e1.Id, Attendee__c = attendees[0].Id, Reg_Date__c = Date.today(), Status__c = 'Confirmed', Reg_Amount__c = 500, Payment_Status__c = 'Paid'));
regs.add(new Registration__c(Event__c = e1.Id, Attendee__c = attendees[1].Id, Reg_Date__c = Date.today(), Status__c = 'Confirmed', Reg_Amount__c = 500, Payment_Status__c = 'Paid'));
regs.add(new Registration__c(Event__c = e1.Id, Attendee__c = attendees[2].Id, Reg_Date__c = Date.today(), Status__c = 'Confirmed', Reg_Amount__c = 450, Payment_Status__c = 'Pending'));
regs.add(new Registration__c(Event__c = e1.Id, Attendee__c = attendees[4].Id, Reg_Date__c = Date.today(), Status__c = 'Registered', Reg_Amount__c = 500, Payment_Status__c = 'Pending'));
regs.add(new Registration__c(Event__c = e2.Id, Attendee__c = attendees[3].Id, Reg_Date__c = Date.today(), Status__c = 'Confirmed', Reg_Amount__c = 300, Payment_Status__c = 'Paid'));
regs.add(new Registration__c(Event__c = e2.Id, Attendee__c = attendees[5].Id, Reg_Date__c = Date.today(), Status__c = 'Confirmed', Reg_Amount__c = 300, Payment_Status__c = 'Paid'));
regs.add(new Registration__c(Event__c = e3.Id, Attendee__c = attendees[6].Id, Reg_Date__c = Date.today(), Status__c = 'Confirmed', Reg_Amount__c = 200, Payment_Status__c = 'Paid'));
regs.add(new Registration__c(Event__c = e3.Id, Attendee__c = attendees[7].Id, Reg_Date__c = Date.today(), Status__c = 'Confirmed', Reg_Amount__c = 200, Payment_Status__c = 'Pending'));
regs.add(new Registration__c(Event__c = e4.Id, Attendee__c = attendees[8].Id, Reg_Date__c = Date.today(), Status__c = 'Registered', Reg_Amount__c = 50, Payment_Status__c = 'Pending'));
regs.add(new Registration__c(Event__c = e4.Id, Attendee__c = attendees[9].Id, Reg_Date__c = Date.today(), Status__c = 'Registered', Reg_Amount__c = 50, Payment_Status__c = 'Pending'));
insert regs;

System.debug('=== SEED DATA CREATED SUCCESSFULLY ===');
System.debug('Venues: ' + [SELECT COUNT() FROM Venue__c]);
System.debug('Events: ' + [SELECT COUNT() FROM Event__c]);
System.debug('Attendees: ' + [SELECT COUNT() FROM Attendee__c]);
System.debug('Registrations: ' + [SELECT COUNT() FROM Registration__c]);

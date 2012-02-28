# Newman-Scheduler
## a scheduling app for Newman

### Example interactions

#### 1. Send in your weekly availability.

    From: Flynn <flynnflys@example.com>
    To: c+availability@test.com
    Subject: 12-Mar-2012 -04:00

    Mon Tue Wed
    1pm - 3pm
    
    
#### 2. Send an event proposal to the mailing list.

    From: Sal <snoopymcbeagle@example.com>
    To: c+picnic.schedule-create@test.com
    Subject: A picnic

    week of Mar 12
    90 minutes
    
Subscribers to the list get an alert to send in their availability.

    From: On behalf of snoopymcbeagle@example.com <c+picnic@test.com>
    Reply-To: c+availability@test.com
    Bcc: <all subscribers>
    Subject: [A picnic] Requesting your availability

    Proposed time:
      week of Mon 12 Mar 
      1hr 30min

    Note there are 3 current subscribers to this list.
    
    
#### 3. Request a list of the current best available times for the event.

    From: Flynn <flynnflys@example.com>
    To: c+picnic.schedule-list@test.com

Everyone on the list gets the response:

    From: c+picnic@test.com
    Bcc: <all subscribers>
    Subject: [A picnic] Best times to meet
    
    week of Mon 12 Mar (1hr 30min) 
    ------------------------------
    Mon 12 Mar  3:00pm UTC -  6:00pm UTC
      Hoban Washburne
      Inara Serra
      Jayne Cobb
      Malcolm Reynolds
      Zoe Washburne
    Wed 14 Mar  3:00pm UTC -  6:00pm UTC
      Inara Serra
      Jayne Cobb
      Zoe Washburne
    Thu 15 Mar  3:00pm UTC -  6:00pm UTC
      Inara Serra
      Jayne Cobb
      Zoe Washburne

#### 4. Request a list of someone's available times for the event.

    From: Sal <snoopymcbeagle@example.com>
    To: c+picnic.schedule-show@test.com
    Subject: flynnflys@example.com

Only the requester gets the response:

    From: c+picnic@test.com
    To: snoopymcbeagle@example.com
    Subject: [A picnic] Available times for: flynnflys@example.com
    
    week of Mon 12 Mar (1hr 30min) 
    ------------------------------
    Mon 12 Mar,  5:00pm UTC -  7:00pm UTC
    Tue 13 Mar,  5:00pm UTC -  7:00pm UTC
    Wed 14 Mar,  5:00pm UTC -  7:00pm UTC
    

### Dependencies

  - [Newman](https://github.com/mendicant-university/newman)
  - [Portera](https://github.com/ericgj/portera)
  

### Remaining work

  - test with mail_whale downstream from it
  

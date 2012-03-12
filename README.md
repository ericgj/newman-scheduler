# Newman-Scheduler
## a scheduling app for Newman

### Example interactions

Say we have a mailing list named _firefly_, and members send to the address
_c+firefly@test.com_.
 
#### 1. Propose an event to the mailing list.

    From: Hoban Washburne <hoban@foo.com>
    To: c+firefly.event-new@test.com
    Subject: Availability for a picnic | week of Mar 19 | 90 minutes

    Hello comrades, can we picnic this week?
    
(The last two |-delimited fields of the subject are interpreted as the range of 
dates and time duration of the event. If they aren't given, the sender will get
an error reply describing the syntax with examples).

Subscribers to the list get the email forwarded with instructions to send in 
their availability. The reply-to address is the availability address, so they
can simply reply to the email with their availability.

    From: On behalf of Hoban Washburne <c+firefly@test.com>
    Reply-To: c+firefly.event-avail-12345@test.com
    Bcc: <all subscribers>
    Subject: Availability for a picnic | week of Mar 19 | 90 minutes

    Hello comrades, can we picnic this week?
    
    -----
    This email was generated by newman-scheduler

    To share your availability for this event, send an email to:
      c+firefly.event-avail-12345@test.com

    To see the current best times for scheduling, send an email to:
      c+firefly.event-sched-12345@test.com   

    For general instructions, send an email to:
      c+firefly.event-usage@test.com
      
       
#### 2. Participants send in their availability:

    From: Inara Serra <inaras@foo.com>
    To: c+firefly.event-avail-12345@test.com
    Subject: RE: Availability for a picnic

    Mon Tue Thu
    00:00 - 24:59
    
------
    
    From: Jayne Cobb <jcobb@foo.com>
    To: c+firefly.event-avail-12345@test.com
    Subject: RE: Availability for a picnic

    -04:00
    Mon Tue Wed Thu Fri
    11:00 - 14:00
    
    
#### 3. Request a list of the current best available times for the event.

    From: Hoban Washburne <hoban@foo.com>
    To: c+firefly.event-sched-12345@test.com

Note any participant can request this. Sender gets the response:

    From: Event scheduler <c+picnic@test.com>
    To: Hoban Washburne <hoban@foo.com>
    Reply-To: c+firefly.event-sched-12345@test.com
    Subject: a picnic - week of Mar 19, 90 minutes
    
    5 of 6 participants have responded.*
    
    week of Mon 19 Mar (1hr 30min) 
    ------------------------------
    Mon 19 Mar  3:00pm UTC -  6:00pm UTC
      Hoban Washburne
      Inara Serra
      Jayne Cobb
      Malcolm Reynolds
      Zoe Washburne
    Wed 21 Mar  3:00pm UTC -  6:00pm UTC
      Inara Serra
      Jayne Cobb
      Zoe Washburne
    Thu 23 Mar  3:00pm UTC -  6:00pm UTC
      Inara Serra
      Jayne Cobb
      Zoe Washburne

    [*] Availability still needed for:
          Maxx Williams <maxxy@foo.com> 

    -----
    This email was generated by newman-scheduler

    To share your availability for this event, send an email to:
      c+firefly.event-avail-12345@test.com

    To see the current best times for scheduling, send an email to:
      c+firefly.event-sched-12345@test.com   

    For general instructions, send an email to:
      c+firefly.event-usage@test.com

          

### Dependencies

  - [Newman](https://github.com/mendicant-university/newman)
  - [Portera](https://github.com/ericgj/portera)
  

### Remaining work


### License

Copyright (c) 2012 Eric Gjertsen

Permission is hereby granted, free of charge, to any person obtaining a copy of 
this software and associated documentation files (the "Software"), to deal in 
the Software without restriction, including without limitation the rights to 
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
 the Software, and to permit persons to whom the Software is furnished to do so,
 subject to the following conditions:

The above copyright notice and this permission notice shall be included in all 
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
 FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR 
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER 
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN 
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

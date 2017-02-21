# Salesforce-Approval-Process-Reminders

Following tool may be used for sending email reminders for pending approval in approval process in specific 
interval. 
The reminders will be keep sending until the related record be approved.

Note: the tool use Salesforce standard scheduling system and it scheduled to run every hour. 
This means that the reminders 
might not be accurate. E.g. If record was submitted for approval 
at 9:30 AM, and you setup reminders after 24 Hours, the 
reminder will be send at 10:00 AM (next day).
 If you need it to be accurate you can expose it at service and call it with 
external tool.

Please refer to salesforce Schedul limits for other limitations: 
https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_scheduler.htm

Components:
Custom objects:

1. Approval Process Reminder 

Setup for sending reminders for specific approval process

Related Fields:
  
	Approval Process Reminder Name- Name of the process
  
	Related Approval Process- Related approval process Name
  
	Related Object- Related object of the approval process (should be object API name)
  
	Reminder After (H) - After how many hours send each reminder
  
	Business Hours - Lookup for Business Hours in Salesforce. This will indicate which days/hours count for this process
  
	Additional Recipient 1    
  
	Additional Recipient 2 - Additional recipients for the reminders, other then the approver. Those fields can hold either u
				sers Id field from the relevant records or fields from the user approver. 
     
                           e.g:
				OwnerId -->Send to the owner of the related record in the approval process

  	                        User.ManagerId-->Send to the manager of the approver
  
	Alert Recipient 1 From Level
  
	Alert Recipient 2 From Level - Indicate from which level of reminders send to each of the additional recipient First 
					alert is level 1, Second is level 2, and so on...

Buttons in Object:
  
	Schedule - Schedule the job
  
	Abort - Abort the schedule job from running

2. Approval Process Record

Relation for approver in specific approval. 

This record shouldn't be created manually, it will be created and maintain by the process.

Related Fields:
  
	Approval Process Reminder - Lookup for the parent approval process reminder setup
  
	Status- Status of this approval. Pending/Approved
  
	Approver - Lookup to the approver user
  
	Approver Name- Formula. Approver Name
  
	Additional Recipient 1   
  
	Additional Recipient 2 - Lookups to the additional recipients
  
	Alerts Sent- Number alerts that was sent
  
	Interval- Formula. After how many hours to send alert
  
	Pending Hours- Number of hours the record is pending approval
  
	ProcessInstance- Id of the processInstance of the approval in salesforce.
  
	Record Id- Id of the record in approval process
  
	Record Link- Link to the record in approval process
  
	Record Name - Record Type + Name of the record in approval process (e.g.: Opportunity: Test Opportunity)

Additional Components:
  
	Apex Trigger: ApprovalProcessReminderTrigger
    Contain some validation regarding the setup in Approval Process Reminder
    
  Apex Page: ScheduleJobNextRun
  Controller Class: vf_ScheduleJobNextRun
    This page embedded inside the page layout of Approval Process Reminder, and show the last and next run of the job.
    
  Workflow rule: WF - Approval Process Reminder
    Run every time Approval Process Record is created or the Alerts Sent value is changed (it increased by code).

	Workflow Email Alert: Email Alert - Approval Process Reminder
    Email alert used by the work flow

	Email Template: Approval Process Reminders
    Email template for the email alert

	Apex class: clsApprovalReminderUtils
    This class receive as parameter the approval process name, and search for pending approval record
    
  
	
	Apex class: ScheduleApprovalReminders
    Implement Salesfore scheduler for scheduling the job
	
	Apex test class: clsApprovalReminderUtilsTest
    Test class for the process.
    
		Notes: 
 1.It is known issue in Salesforce that test classes cannot have ProcessInstanceHistory 
			(https://success.salesforce.com/issues_view?id=a1p30000000SWMFAA4), 
therefore in test class I'm using 
			ViewAllData=true
    
			2.The test querying random approval process and trying to use it, in case it have entry criteria or the 
			relevant record failed to be insert, the coverage might be lower.
    
			You can implement your own test that will match your business logic.

/**
* 	Liron Cohen
* 	@class vf_ScheduleJobNextRun
* 	@description 	Standard controller for the page:  ScheduleJobNextRun.
*					Displaying the last and next run of specific job
*/  

public class vf_ScheduleJobNextRun {
	
	public vf_ScheduleJobNextRun(ApexPages.StandardController controller){
		String approvalSetupId=ApexPages.currentPage().getParameters().get('id');
		String name=[select name from Approval_Process_Reminder__c where id=:approvalSetupId].Name;
		

		list<CronTrigger> l_cr = [SELECT id, state, NextFireTime, PreviousFireTime, CronJobDetail.Name FROM CronTrigger WHERE CronJobDetail.Name =:name];
		
		if(l_cr.isEmpty())
			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO,  'Process is not schedule.'));
		else{
			
			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, 
					'<b>Status:</b> ' + l_cr.get(0).state + 
					'<br/><b>Last run:</b>' + (l_cr.get(0).PreviousFireTime!=null ? l_cr.get(0).PreviousFireTime.format() : 'N/A') + 
					'<br/><b>Next run:</b>' + l_cr.get(0).NextFireTime.format()));
		}
	}
    
}

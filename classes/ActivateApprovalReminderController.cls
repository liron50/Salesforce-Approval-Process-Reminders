public class ActivateApprovalReminderController{

    public boolean isRunning {get; set;}

    public ActivateApprovalReminderController(){
        init();
    }
    
    public ActivateApprovalReminderController(ApexPages.StandardController sc){
        init();
    }
    
    public PageReference activateProcess(){
    
        String retMsg = ApprovalReminderUtils.scheduleProcess();
        
        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, retMsg));
              
        init();
        
        return null;
    }
    
    
    public PageReference stopProcess(){
        String retMsg = ApprovalReminderUtils.abortProcess();

        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, retMsg));
              
        init();
        
        return null;
    }
    
    
    public void init(){
        list<CronTrigger> l_cr = [SELECT id, state, NextFireTime, PreviousFireTime, CronJobDetail.Name FROM CronTrigger WHERE CronJobDetail.Name ='ApprovalProcessReminders'];
    
        if(l_cr.isEmpty()){
            isRunning = false;
            
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, 
              '<b>Currently the process is not scheduled.</b>'));
        }
        else{
            isRunning = true;
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, 
              '<b>Status:</b> ' + l_cr.get(0).state + 
              '<br/><b>Last run:</b>' + (l_cr.get(0).PreviousFireTime!=null ? l_cr.get(0).PreviousFireTime.format() : 'N/A') + 
              '<br/><b>Next run:</b>' + l_cr.get(0).NextFireTime.format()));
        }
    }
}
public class BatchApprovalReminders implements Database.Batchable<sObject>{

     public Database.QueryLocator start(Database.BatchableContext bc){
        return Database.getQueryLocator('select Id, Related_Approval_Process__c from Approval_Process_Reminder__c where Active__c = true');
    }


    public void execute(Database.BatchableContext bc, List<sObject> lso) {
        
        list<String> l_approvalNames = new list<String>();
        
        for(sobject obj : lso){
            l_approvalNames.add((String)obj.get('Related_Approval_Process__c'));
        }
        
        ApprovalReminderUtils.ApprovalProcessReminderMain(l_approvalNames);
    }
    
    
    public void finish(Database.BatchableContext bc) {

    }
}
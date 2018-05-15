@IsTest
private class NewApprovalReminderControllerTest{

    static testMethod void testNewApprovalSetup(){
    
        Test.startTest();
        
        BusinessHours bh = [select id from BusinessHours limit 1];
        
        ApexPages.StandardController st = new ApexPages.StandardController(new Approval_Process_Reminder__c ());
        NewApprovalReminderController controller = new NewApprovalReminderController(st);
        controller.approvalProcessOptions.get(0).getValue();
        
        if(controller.approvalProcessOptions.size() > 1){
            controller.approvalReminders.Related_Approval_Process__c = controller.approvalProcessOptions.get(1).getValue();
        }
        controller.fetchObjectUsers();
        
        controller.approvalReminders.Business_Hours__c = bh.Id;
        
        controller.saveRecord();
        
        Test.stopTest();
    }
}
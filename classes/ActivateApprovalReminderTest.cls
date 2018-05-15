@IsTest
private class ActivateApprovalReminderTest{

    static testMethod void testActivationProcess(){
    
        Test.startTest();
        
        ActivateApprovalReminderController controller = new ActivateApprovalReminderController();
        controller.activateProcess();
        controller.stopProcess();
        
        Test.stopTest();
    }

}
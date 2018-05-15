@isTest (SeeAllData=true)
private class ApprovalReminderUtilsTest {

    static testMethod void testApprovalReminders() {
        
        Account testAccount = new Account(Name = 'TestAccount1234');
        insert testAccount;
        
        ProcessDefinition approvalProcess;
        
        try{
             approvalProcess = [   select id, DeveloperName,State,Type,TableEnumOrId 
                                                from ProcessDefinition 
                                                where state = 'Active' and type='Approval' limit 1];
        }
        catch(Exception ex){
            System.debug('No active approval process. Might have lower coverage');
        }
        
        //Get first Business Hours records
        BusinessHours bh = [select id from BusinessHours limit 1];
      
        //Create Approval Process Reminders.
        //Should contain value approval process and the correct Related object
        Approval_Process_Reminder__c apr = new Approval_Process_Reminder__c(Name='Test Reminder', 
                                        Related_Object__c=approvalProcess != null ? approvalProcess.TableEnumOrId : 'Account', 
                                        Related_Approval_Process__c=approvalProcess != null ? approvalProcess.DeveloperName : 'AccountAPR',
                                        Reminder_After__c=-1,
                                        Additional_Recipient_1__c='OwnerId',
                                        Alert_Recipient_1_From_Level__c=1,
                                        Alert_Recipient_2_From_Level__c=1,
                                        Business_Hours__c=bh.id);
        insert apr;                                        
        
        
        Test.startTest();
        
        try{
            //Create record related to the approval process
            Schema.SObjectType targetType = Schema.getGlobalDescribe().get(approvalProcess != null ? approvalProcess.TableEnumOrId : 'Account');
            sObject obj = targetType.newSObject();
            insert obj;
            
            //Submit the approval request
            Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
            req.setNextApproverIds(new Id[] {UserInfo.getUserId()});
            req.setObjectId(obj.Id);
            Approval.ProcessResult result = Approval.process(req);
        }
        catch(Exception ex){
            system.debug('Failed to create/submit:' + ex.getMessage());
        }

        //First run - create new APR records
        Database.executeBatch(new BatchApprovalReminders(), 10);
        
        //Second run - update existsing APR records
        Database.executeBatch(new BatchApprovalReminders(), 10);
        
        //Schedule and Abort functions
        ApprovalReminderUtils.scheduleProcess();
        ApprovalReminderUtils.abortProcess();
        
        Datetime dt = Datetime.now().addMinutes(1);
        String CRON_EXP = '0 '+ dt.minute() + ' * ' + dt.day() + ' ' + dt.month() + ' ? ' + dt.year();
        String jobId = System.schedule('Sample_Heading', CRON_EXP, new ScheduleApprovalReminders() );   
        
        Test.stopTest();
        
    }
}
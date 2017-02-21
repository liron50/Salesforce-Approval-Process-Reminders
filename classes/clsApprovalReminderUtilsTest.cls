/**
*	Copyright (c) tgerm.com
*	All rights reserved.
*	Redistribution and use in source and binary forms, with or without
*	modification, are permitted provided that the following conditions
*	are met:
*	1. Redistributions of source code must retain the above copyright
*   notice, this list of conditions and the following disclaimer.
*	2. Redistributions in binary form must reproduce the above copyright
*   notice, this list of conditions and the following disclaimer in the
*   documentation and/or other materials provided with the distribution.
*	3. The name of the author may not be used to endorse or promote products
*   derived from this software without specific prior written permission.
*
*	THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR
*	IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
*	OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
*	IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, 
*	INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
*	NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
*	DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
*	THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
*	(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
*	THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/ 

/**
* 	Liron Cohen
* 	@class clsApprovalReminderUtilsTest
* 	@Description Test class for sending email alert for pending approval processes 
*/  
@isTest (SeeAllData=true)
private class clsApprovalReminderUtilsTest {

    static testMethod void testApprovalReminders() {
      	
      	
      	ProcessDefinition approvalProcess = [	select id, DeveloperName,State,Type,TableEnumOrId 
      											from ProcessDefinition 
      											where state = 'Active' and type='Approval'];
      	
      	//Get first Business Hours records
      	BusinessHours bh = [select id from BusinessHours limit 1];
      
      	//Create Approval Process Reminders.
      	//Should contain value approval process and the correct Related object
        Approval_Process_Reminder__c apr = new Approval_Process_Reminder__c(Name='Test Reminder', 
                                        Related_Object__c=approvalProcess.TableEnumOrId, 
                                        Related_Approval_Process__c=approvalProcess.DeveloperName,
                                        Reminder_After__c=-1,
                                        Additional_Recipient_1__c='User.ManagerId',
                                        Additional_Recipient_2__c='OwnerId',
                                        Alert_Recipient_1_From_Level__c=1,
                                        Alert_Recipient_2_From_Level__c=1,
                                        Business_Hours__c=bh.id);
        insert apr;                                        
        
        
        Test.startTest();
        
        try{
	        //Create record related to the approval process
	        Schema.SObjectType targetType = Schema.getGlobalDescribe().get(approvalProcess.TableEnumOrId);
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
        clsApprovalReminderUtils.ApprovalProcessReminderMain(apr.Name);
        
        //Second run - update existsing APR records
        clsApprovalReminderUtils.ApprovalProcessReminderMain(apr.Name);
        
        //Schedule and Abort functions
        clsApprovalReminderUtils.scheduleProcess(apr.Name);
        clsApprovalReminderUtils.abortProcess(apr.Name);
        
        Test.stopTest();
        
    }
}

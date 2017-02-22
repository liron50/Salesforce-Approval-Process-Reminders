/*
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
* 
*	@class clsApprovalReminderUtils
*	@Description Class for sending email alert for pending approval processes 
*/  
global class clsApprovalReminderUtils {
    
    
    public static void ApprovalProcessReminderMain(String approvalName){
        try{
        
            //Retrieve the relevant approval process reminder setup
            Approval_Process_Reminder__c reminderSetup =    [select id, Related_Object__c, Related_Approval_Process__c, Reminder_After__c, Additional_Recipient_1__c, Additional_Recipient_2__c,
                                                                    Alert_Recipient_1_From_Level__c, Alert_Recipient_2_From_Level__c, Business_Hours__c,
                                                                (   select id, Status__c, Record_Id__c, ProcessInstance_Id__c, Alerts_Sent__c,Approver__c
                                                                    from Approval_Process_Records__r where status__c = 'Pending')
                                                             from Approval_Process_Reminder__c where name =:approvalName];
            
            //per each key (record Id from approval + processInstanceId + approverId) its Approval Process Record (if exists)
            map<String, Approval_Process_Record__c> m_recId_APR = new map<String, Approval_Process_Record__c>();
            
            for(Approval_Process_Record__c apr : reminderSetup.Approval_Process_Records__r){
                m_recId_APR.put(apr.Record_ID__c + '_' + apr.ProcessInstance_Id__c + '_' + apr.Approver__c, apr);
            }
                
            //list of APR recors for insert
            list<Approval_Process_Record__c> l_newAPR = new list<Approval_Process_Record__c>();
            
            //Set of APR records that was increased by 1
            set<Id> s_aprId = new set<Id>();
            
            //list of ProcessInstance
            list<ProcessInstance> l_processInstance = new list<ProcessInstance>();
            
            //list of records Id in approval process
            list<Id> l_TargetObjId = new list<Id>();
            
            //map per each apprver it's ProcessInstanceHistory record
            map<Id, ProcessInstanceHistory> m_Actor_pih = new map<Id, ProcessInstanceHistory>();
            
            //map per each user it's User record
            map<Id, User> m_Actor_User = new map<Id, User>();
            
            for ( ProcessInstance pi:   [   SELECT Id, Status, TargetObjectId, LastModifiedDate, 
                                                (SELECT Id, ActorId, StepStatus, CreatedDate FROM StepsAndWorkitems where StepStatus='Pending')
                                            FROM ProcessInstance 
                                            where Status IN ('Pending','Hold', 'Reassigned')
                                                and ProcessDefinition.Name = :reminderSetup.Related_Approval_Process__c]) {
                l_processInstance.add(pi);
                  
                l_TargetObjId.add(pi.TargetObjectId);
                
                for (ProcessInstanceHistory pih : pi.StepsAndWorkItems) {
                    m_Actor_pih.put(pih.ActorId, pih);
                }
             }
            
            
            if(!l_TargetObjId.isEmpty()){
                //Should collect all relevant records Ids which currently in approval process, and query 
                //their related users (According to the setup in approval reminder)
                String sql = 'select id';
                
                //Query from User object
                String sqlUsers = '';
            
                if(reminderSetup.Additional_Recipient_1__c != null){
                
                    //If additional recipient start with user query the field from the user SQL, otherwise from the record SQL
                    if(reminderSetup.Additional_Recipient_1__c.startsWith('User.')){   
                        sqlUsers += '' + reminderSetup.Additional_Recipient_1__c.subStringAfter('User.') + ',';
                    }
                    else{
                        sql += ',' + reminderSetup.Additional_Recipient_1__c;
                    }
                }
                if(reminderSetup.Additional_Recipient_2__c != null){
                    if(reminderSetup.Additional_Recipient_2__c.startsWith('User.')){
                        sqlUsers += '' + reminderSetup.Additional_Recipient_2__c.subStringAfter('User.') + ',';
                    }
                    else{
                        sql += ',' + reminderSetup.Additional_Recipient_2__c;
                    }
                }
                
                //Query data from related users
                if(sqlUsers != ''){
                    set<ID> usersIdSet = m_Actor_pih.keyset();
                    
                    //Query user data
                    for(User u : database.query('select ' + sqlUsers.subString(0, sqlUsers.length()-1) + ' from user where id in :usersIdSet')){
                        m_Actor_User.put(u.id, u);
                    }
                }
            
                //Query data from the object in the approval process
                map<Id, sObject> m_targetObject = new map<Id, sObject>();
                for(sObject obj : Database.query(sql + ' from ' + reminderSetup.Related_Object__c + ' where id in :l_TargetObjId')){
                    m_targetObject.put(obj.id, obj);
                }
                
                //Loop over all approval process records that were retrieved
                for ( ProcessInstance pi:   l_processInstance) {
                            
                    //Per each pending approver
                    for (ProcessInstanceHistory pih : pi.StepsAndWorkItems) {
                        
                        //Calculate the hours difference from time processinstance was created until now
                        Double pendingHours = (Double) BusinessHours.diff(reminderSetup.Business_Hours__c, pih.CreatedDate, system.now())/1000/60/60;
                            
                        system.debug('###pendingHours:' + pendingHours);
                        
                        //If target object id inside the map, means alert was already sent for this record before
                        if(m_recId_APR.containsKey(pi.targetObjectId + '_' + pi.id + '_' + pih.ActorId)){
                            
                            //calculate if hours that approval is pending divded by the alerts that were sent is greater than current number of alerts
                            //If criteria aply - means it time to send another reminder
                            if(math.Floor(pendingHours/reminderSetup.Reminder_After__c) > m_recId_APR.get(pi.targetObjectId + '_' + pi.id + '_' + pih.ActorId).Alerts_Sent__c){
                                
                                //Increase the Alert Send by 1, this will run the workflow rule
                                m_recId_APR.get(pi.targetObjectId + '_' + pi.id + '_' + pih.ActorId).Alerts_Sent__c ++;
                                
                                m_recId_APR.get(pi.targetObjectId + '_' + pi.id + '_' + pih.ActorId).Pending_Hours__c = pendingHours;
                                
                                /*if(reminderSetup.Alert_Recipient_1_From_Level__c <=  m_recId_APR.get(pi.targetObjectId + '_' + pi.id + '_' + pih.ActorId).Alerts_Sent__c && reminderSetup.Additional_Recipient_1__c != null){
                                    if(reminderSetup.Additional_Recipient_1__c.startsWith('User.')){
                                        m_recId_APR.get(pi.targetObjectId + '_' + pi.id + '_' + pih.ActorId).Additional_Recipient_1__c = (Id) m_Actor_User.get(pih.ActorId).get(reminderSetup.Additional_Recipient_1__c.subStringAfter('User.'));
                                    }
                                    else{
                                        m_recId_APR.get(pi.targetObjectId + '_' + pi.id + '_' + pih.ActorId).Additional_Recipient_1__c = (Id) m_targetObject.get(pi.targetObjectId).get(reminderSetup.Additional_Recipient_1__c);
                                    }
                                }
                                
                                if(reminderSetup.Alert_Recipient_2_From_Level__c <=  m_recId_APR.get(pi.targetObjectId + '_' + pi.id + '_' + pih.ActorId).Alerts_Sent__c && reminderSetup.Additional_Recipient_2__c != null){
                                    if(reminderSetup.Additional_Recipient_2__c.startsWith('User.')){
                                        m_recId_APR.get(pi.targetObjectId + '_' + pi.id + '_' + pih.ActorId).Additional_Recipient_2__c = (Id) m_Actor_User.get(pih.ActorId).get(reminderSetup.Additional_Recipient_2__c.subStringAfter('User.'));
                                    }
                                    else{
                                        m_recId_APR.get(pi.targetObjectId + '_' + pi.id + '_' + pih.ActorId).Additional_Recipient_2__c = (Id) m_targetObject.get(pi.targetObjectId).get(reminderSetup.Additional_Recipient_2__c);
                                    }
                                }*/
                            }
                            
                            //This will be used later. Need to know which Approval Process Records was increased. Other
                            //records will be updated with Status = 'Approved'
                            s_aprId.add(m_recId_APR.get(pi.targetObjectId + '_' + pi.id + '_' + pih.ActorId).id);
                        }
                        else{   //No previous alert was sent for this record
                            
                            //Pending hour is more than the setup, should send first alert
                            if(pendingHours > reminderSetup.Reminder_After__c){ 
                                
                                //Get the relevant additional recipients
                                Id addRecipient1, addRecipient2;
                                
                                if(reminderSetup.Alert_Recipient_1_From_Level__c <=  1 && reminderSetup.Additional_Recipient_1__c != null){
                                    if(reminderSetup.Additional_Recipient_1__c.startsWith('User.')){
                                        addRecipient1 = (Id) m_Actor_User.get(pih.ActorId).get(reminderSetup.Additional_Recipient_1__c.subStringAfter('User.'));
                                    }
                                    else{
                                        addRecipient1 = (Id) m_targetObject.get(pi.targetObjectId).get(reminderSetup.Additional_Recipient_1__c);
                                    }
                                }
                                
                                if(reminderSetup.Alert_Recipient_2_From_Level__c <=  1 && reminderSetup.Additional_Recipient_2__c != null){
                                    if(reminderSetup.Additional_Recipient_2__c.startsWith('User.')){
                                        addRecipient2 = (Id) m_Actor_User.get(pih.ActorId).get(reminderSetup.Additional_Recipient_2__c.subStringAfter('User.'));
                                    }
                                    else{
                                        addRecipient2 = (Id) m_targetObject.get(pi.targetObjectId).get(reminderSetup.Additional_Recipient_2__c);
                                    }
                                }
                                
                                //Add new Approval Process Record        
                                l_newAPR.add(new Approval_Process_Record__c(    Approval_Process_Reminder__c = reminderSetup.id,
                                                                                Status__c = 'Pending', 
                                                                                Record_Id__c = pi.targetObjectId, 
                                                                                ProcessInstance_Id__c = pi.id, 
                                                                                Alerts_Sent__c = 1,
                                                                                Pending_Hours__c = pendingHours,
                                                                                Approver__c = pih.ActorId,
                                                                                Additional_Recipient_1__c = addRecipient1 != null ? addRecipient1 : null,
                                                                                Additional_Recipient_2__c = addRecipient2 != null ? addRecipient2 : null));
                            }
                        }
                    }                           
                    
                }
                    
                //Evaluate old APR records that are no longer in the approval process. Should update their status to 'Approved'
                for(Approval_Process_Record__c apr : reminderSetup.Approval_Process_Records__r){
                    //if not update earlier
                    if(!s_aprId.contains(apr.id)){
                        apr.Status__c = 'Approved';
                    }
                }
                    
                //New Approval Process Records for insert
                if(! l_newAPR.isEmpty()){
                    insert l_newAPR;
                }
                
                //Update all existing Approval Process Records. This list contain 3 type of records:
                //1.Records that Alert_Sent was increased, and now another reminder will be send for them
                //2.Records that are no longer found in the pending ProcessInstances, therefore will be upadated to status 'Approved'
                //3.Records without any change in this run
                if(!reminderSetup.Approval_Process_Records__r.isEmpty()){
                    update reminderSetup.Approval_Process_Records__r;
                }
            }
        }
        catch(Exception e){
            //Might want to sent email alert to admin user, and notify the issue
            system.debug('###' + e);
        }
    }
    
    
    
    
    
    //###########################################
    //### Schedule job to run
    //###########################################   
    webservice static String scheduleProcess(String approvalReminderName){
        String retMsg;
        
        try{
            list<CronTrigger> l_cr = [SELECT id, CronExpression, TimesTriggered, CronJobDetail.Name FROM CronTrigger WHERE CronJobDetail.Name =:approvalReminderName limit 1];
        
            if(l_cr.isEmpty()){
                String jobID = system.schedule(approvalReminderName, '0 0 * * * ?', new ScheduleApprovalReminders());
                
                retMsg = 'Process was scheduled';
            }
            else{
                retMSg = 'Process is already schduled.';
            }
        }
        catch(Exception e){
            retMsg = 'Error: ' + e.getMessage();
        }
        
        return retMsg;
    }

    //###########################################
    //### Abord job that is running
    //###########################################   
    webservice static String abortProcess(String approvalReminderName){
        string retMsg;
        try{
            list<CronTrigger> l_cr = [SELECT id, CronExpression, TimesTriggered, CronJobDetail.Name FROM CronTrigger WHERE CronJobDetail.Name =:approvalReminderName limit 1];
        
            if(l_cr.isEmpty())
                retMsg = 'Process is not schedule';
            else{
                System.abortJob(l_cr.get(0).id);
            
                retMSg = 'Process was aborted';
            }
        }
        catch(Exception e){
            retMsg = 'Error: ' + e.getMessage();
        }
            
        return retMsg;
    }
    
    
}

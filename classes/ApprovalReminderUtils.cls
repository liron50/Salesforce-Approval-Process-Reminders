global class ApprovalReminderUtils {
    
    
    public static void ApprovalProcessReminderMain(list<String> l_approvalNames){
        try{
        
            //Retrieve the relevant approval process reminder setup
            list<Approval_Process_Reminder__c> l_reminderSetup =    
                        [select id, Related_Object__c, Related_Approval_Process__c, Reminder_After__c, Business_Hours__c,
                            Additional_Recipient_1__c, Additional_Recipient_2__c,Additional_Recipient_3__c, Additional_Recipient_4__c, Additional_Recipient_5__c, Additional_Recipient_6__c,
                            Alert_Recipient_1_From_Level__c, Alert_Recipient_2_From_Level__c, Alert_Recipient_3_From_Level__c, Alert_Recipient_4_From_Level__c, Alert_Recipient_5_From_Level__c, Alert_Recipient_6_From_Level__c,
                            (select id, Status__c, Record_Id__c, ProcessInstance_Id__c, Alerts_Sent__c,Approver__c from Approval_Process_Records__r where status__c = 'Pending')
                        from Approval_Process_Reminder__c
                        where Related_Approval_Process__c In :l_approvalNames 
                            and Active__c = true];
            
            //Map - per each approval process, some related properties
            map<String, ApprovalProcessProperty> m_approvalProp = new map<String, ApprovalProcessProperty>();
            
            //list of APR recors for insert
            list<Approval_Process_Record__c> l_newAPR = new list<Approval_Process_Record__c>();    
            
            //list of APR record for update
            list<Approval_Process_Record__c> l_updAPR = new list<Approval_Process_Record__c>();    
            
            //Set of APR records that was increased by 1
            set<Id> s_aprId = new set<Id>();
            
            //set of users that exists as actor in the workItems 
            set<Id> s_userIds = new set<Id>();
            
            //per each key (record Id from approval + processInstanceId + approverId) its Approval Process Record (if exists)
                map<String, Approval_Process_Record__c> m_recId_APR = new map<String, Approval_Process_Record__c>();
                
            for(Approval_Process_Reminder__c reminderSetup : l_reminderSetup){
                
                System.debug('####' + reminderSetup.Related_Approval_Process__c);
                
                m_approvalProp.put(
                    reminderSetup.Related_Approval_Process__c, new ApprovalProcessProperty(reminderSetup));
                
                //list of records Id in approval process
                list<Id> l_TargetObjId = new list<Id>();
            
                for(Approval_Process_Record__c apr : reminderSetup.Approval_Process_Records__r){
                    m_recId_APR.put(apr.Record_ID__c + '_' + apr.ProcessInstance_Id__c + '_' + apr.Approver__c, apr);
                }
            }
            
            if(Test.isRunningTest()){
                //Create mock data
                Account acc = [select Id from Account limit 1];
                
                ProcessInstanceRecord pi = new ProcessInstanceRecord('testId', 'Pending', acc.Id, System.Now() - 1);
                
                ProcessInstanceItemRecord processInstanceItemRec = new ProcessInstanceItemRecord(UserInfo.getUserId(), 'Pending', System.Now()-3);
                        
                s_userIds.add(UserInfo.getUserId());
                        
                pi.addItem(processInstanceItemRec);
                
                m_approvalProp.get(l_reminderSetup.get(0).Related_Approval_Process__c).addRecordId(acc.Id);
                m_approvalProp.get(l_reminderSetup.get(0).Related_Approval_Process__c).addProcessInstance(pi);
            }
            else{
                System.debug('####' + m_approvalProp.keySet());
                
                for ( ProcessInstance pi:   [   SELECT Id, Status, TargetObjectId, LastModifiedDate, ProcessDefinition.DeveloperName, 
                                                    (SELECT Id, ActorId, StepStatus, CreatedDate FROM StepsAndWorkitems where StepStatus='Pending')
                                                FROM ProcessInstance 
                                                where Status IN ('Pending','Hold','Reassigned','NoResponse')
                                                    and ProcessDefinition.DeveloperName IN :m_approvalProp.keySet()]) {
                                                
                    ProcessInstanceRecord processInstanceRec = new ProcessInstanceRecord(pi.Id, pi.Status, pi.TargetObjectId, pi.LastModifiedDate);
                    
                    for (ProcessInstanceHistory pih : pi.StepsAndWorkItems) {
                        s_userIds.add(pih.ActorId);
                        
                        ProcessInstanceItemRecord processInstanceItemRec = new ProcessInstanceItemRecord(pih.ActorId, pih.StepStatus, pih.CreatedDate);
                        
                        processInstanceRec.addItem(processInstanceItemRec);
                    }
                    
                    m_approvalProp.get(pi.ProcessDefinition.DeveloperName).addRecordId(pi.TargetObjectId);
                    m_approvalProp.get(pi.ProcessDefinition.DeveloperName).addProcessInstance(processInstanceRec);
                }
            }
            
            if(! s_userIds.isEmpty()){
            
                //In each approval process properties initialaze the related object with users fields
                for(String approvalKey : m_approvalProp.keySet()){
                    m_approvalProp.get(approvalKey).queryRelatedObjects();
                    
                    //Loop over approval process instance
                    for(ProcessInstanceRecord pi : m_approvalProp.get(approvalKey).l_instanceRecords){
                    
                        //Per each pending approver
                        for (ProcessInstanceItemRecord pih : pi.items) {
                            
                            //Calculate the hours difference from time processinstance was created until now
                            Double pendingHours = (Double) BusinessHours.diff(
                                m_approvalProp.get(approvalKey).approvalProcessReminder.Business_Hours__c, pih.CreatedDate, system.now())/1000/60/60;
                                
                            system.debug('###pendingHours:' + pendingHours);
                            
                            //If target object id inside the map, means alert was already sent for this record before
                            if(m_recId_APR.containsKey(pi.targetObjectId + '_' + pi.id + '_' + pih.ActorId)){
                                //calculate if hours that approval is pending divded by the alerts that were sent is greater than current number of alerts
                                //If criteria aply - means it time to send another reminder
                                if(math.Floor(pendingHours/m_approvalProp.get(approvalKey).approvalProcessReminder.Reminder_After__c) > m_recId_APR.get(pi.targetObjectId + '_' + pi.id + '_' + pih.ActorId).Alerts_Sent__c){
                                
                                    //Increase the Alert Send by 1, this will run the workflow rule
                                    m_recId_APR.get(pi.targetObjectId + '_' + pi.id + '_' + pih.ActorId).Alerts_Sent__c ++;
                                
                                    m_recId_APR.get(pi.targetObjectId + '_' + pi.id + '_' + pih.ActorId).Pending_Hours__c = pendingHours;
                                
                                    //Populate the new recipients if needed
                                    integer alertCounter = Integer.valueOf(m_recId_APR.get(pi.targetObjectId + '_' + pi.id + '_' + pih.ActorId).Alerts_Sent__c);
                                    
                                    m_recId_APR.get(pi.targetObjectId + '_' + pi.id + '_' + pih.ActorId).Additional_Recipient_1__c = m_approvalProp.get(approvalKey).getUser(pi.targetObjectId, 1, alertCounter); 
                                    m_recId_APR.get(pi.targetObjectId + '_' + pi.id + '_' + pih.ActorId).Additional_Recipient_2__c = m_approvalProp.get(approvalKey).getUser(pi.targetObjectId, 2, alertCounter); 
                                    m_recId_APR.get(pi.targetObjectId + '_' + pi.id + '_' + pih.ActorId).Additional_Recipient_3__c = m_approvalProp.get(approvalKey).getUser(pi.targetObjectId, 3, alertCounter); 
                                    m_recId_APR.get(pi.targetObjectId + '_' + pi.id + '_' + pih.ActorId).Additional_Recipient_4__c = m_approvalProp.get(approvalKey).getUser(pi.targetObjectId, 4, alertCounter); 
                                    m_recId_APR.get(pi.targetObjectId + '_' + pi.id + '_' + pih.ActorId).Additional_Recipient_5__c = m_approvalProp.get(approvalKey).getUser(pi.targetObjectId, 5, alertCounter); 
                                    m_recId_APR.get(pi.targetObjectId + '_' + pi.id + '_' + pih.ActorId).Additional_Recipient_6__c = m_approvalProp.get(approvalKey).getUser(pi.targetObjectId, 6, alertCounter); 
                                
                                    //This will be used later. Need to know which Approval Process Records was increased. Other
                                    //records will be updated with Status = 'Approved'
                                    s_aprId.add(m_recId_APR.get(pi.targetObjectId + '_' + pi.id + '_' + pih.ActorId).id);
                                }
                            }
                            else{   //No previous alert was sent for this record
                            
                                //Pending hour is more than the setup, should send first alert
                                if(pendingHours > m_approvalProp.get(approvalKey).approvalProcessReminder.Reminder_After__c){ 
                                    //Add new Approval Process Record        
                                    l_newAPR.add(new Approval_Process_Record__c(Approval_Process_Reminder__c = m_approvalProp.get(approvalKey).approvalProcessReminder.id,
                                                                                Status__c = 'Pending', 
                                                                                Record_Id__c = pi.targetObjectId, 
                                                                                ProcessInstance_Id__c = pi.id, 
                                                                                Alerts_Sent__c = 1,
                                                                                Pending_Hours__c = pendingHours,
                                                                                Approver__c = pih.ActorId,
                                                                                Additional_Recipient_1__c = m_approvalProp.get(approvalKey).getUser(pi.targetObjectId, 1, 1),
                                                                                Additional_Recipient_2__c = m_approvalProp.get(approvalKey).getUser(pi.targetObjectId, 2, 1),
                                                                                Additional_Recipient_3__c = m_approvalProp.get(approvalKey).getUser(pi.targetObjectId, 3, 1),
                                                                                Additional_Recipient_4__c = m_approvalProp.get(approvalKey).getUser(pi.targetObjectId, 4, 1),
                                                                                Additional_Recipient_5__c = m_approvalProp.get(approvalKey).getUser(pi.targetObjectId, 5, 1),
                                                                                Additional_Recipient_6__c = m_approvalProp.get(approvalKey).getUser(pi.targetObjectId, 6, 1)));
                                }
                            }
                        }
                    }
                    
                    //Evaluate old APR records that are no longer in the approval process. Should update their status to 'Approved'
                    for(Approval_Process_Record__c apr : m_approvalProp.get(approvalKey).approvalProcessReminder.Approval_Process_Records__r){
                        //if not update earlier
                        if(!s_aprId.contains(apr.id)){
                            apr.Status__c = 'Approved';
                        }
                    }
                    
                    l_updAPR.addAll(m_approvalProp.get(approvalKey).approvalProcessReminder.Approval_Process_Records__r);
                }
                    
                //New Approval Process Records for insert
                if(! l_newAPR.isEmpty()){
                    insert l_newAPR;
                }
                
                //Update all existing Approval Process Records. This list contain 3 type of records:
                //1.Records that Alert_Sent was increased, and now another reminder will be send for them
                //2.Records that are no longer found in the pending ProcessInstances, therefore will be upadated to status 'Approved'
                //3.Records without any change in this run
                if(!l_updAPR.isEmpty()){
                    update l_updAPR; 
                }
            }
        }
        catch(Exception e){
            //Might want to sent email alert to admin user, and notify the issue
            system.debug('###' + e);
        }
    }
    

    public class ApprovalProcessProperty{
        public Approval_Process_Reminder__c approvalProcessReminder;
        public list<String> l_recordsIds;
        public list<ProcessInstanceRecord> l_instanceRecords;
        
        map<String, SObject> m_relatedRecords;
        
        public ApprovalProcessProperty(Approval_Process_Reminder__c pApprovalProcessReminder){
            approvalProcessReminder = pApprovalProcessReminder;
            
            l_recordsIds = new list<String>();
            l_instanceRecords = new list<ProcessInstanceRecord>();
            m_relatedRecords = new map<String, SObject>();
        }
        
        public void addRecordId(String recordId){
            l_recordsIds.add(recordId);
        }
        
        public void addProcessInstance(ProcessInstanceRecord processRecord){
            l_instanceRecords.add(processRecord);
        }
        
        public void queryRelatedObjects(){
            if(!l_recordsIds.isEmpty() 
               && (approvalProcessReminder.Additional_Recipient_1__c != null || approvalProcessReminder.Additional_Recipient_2__c != null)){
                
                //Should collect all relevant records Ids which currently in approval process, and query their related users (According to the setup in approval reminder)
                String sql = 'select id';
                
                if(approvalProcessReminder.Additional_Recipient_1__c != null
                    && approvalProcessReminder.Additional_Recipient_1__c != 'None'){
                    sql += ',' + approvalProcessReminder.Additional_Recipient_1__c;
                }
                if(approvalProcessReminder.Additional_Recipient_2__c != null
                    && approvalProcessReminder.Additional_Recipient_2__c != 'None'){
                    sql += ',' + approvalProcessReminder.Additional_Recipient_2__c;
                }
                
                for(sObject obj : Database.query(sql + ' from ' + approvalProcessReminder.Related_Object__c + ' where id in :l_recordsIds')){
                    m_relatedRecords.put(obj.id, obj);
                }
            }
        }
        
        public String getUser(String recordId, integer recipiantNum, integer approvalLevel){
            if(recipiantNum == 1 
                && approvalProcessReminder.Alert_Recipient_1_From_Level__c <= approvalLevel
                && approvalProcessReminder.Additional_Recipient_1__c != null
                && approvalProcessReminder.Additional_Recipient_1__c != 'None'){
                return (String) m_relatedRecords.get(recordId).get(approvalProcessReminder.Additional_Recipient_1__c);
            }
            else if(recipiantNum == 2 
                && approvalProcessReminder.Alert_Recipient_2_From_Level__c <= approvalLevel
                && approvalProcessReminder.Additional_Recipient_2__c != null
                && approvalProcessReminder.Additional_Recipient_2__c != 'None'){
                return (String) m_relatedRecords.get(recordId).get(approvalProcessReminder.Additional_Recipient_2__c);
            }
            else if(recipiantNum == 3 
                && approvalProcessReminder.Alert_Recipient_3_From_Level__c <= approvalLevel
                && approvalProcessReminder.Additional_Recipient_3__c != null){
                return approvalProcessReminder.Additional_Recipient_3__c;
            }
            else if(recipiantNum == 4 
                && approvalProcessReminder.Alert_Recipient_4_From_Level__c <= approvalLevel
                && approvalProcessReminder.Additional_Recipient_4__c != null){
                return approvalProcessReminder.Additional_Recipient_4__c;
            }
            else if(recipiantNum == 5 
                && approvalProcessReminder.Alert_Recipient_5_From_Level__c <= approvalLevel
                && approvalProcessReminder.Additional_Recipient_5__c != null){
                return approvalProcessReminder.Additional_Recipient_5__c;
            }
            else if(recipiantNum == 6 
                && approvalProcessReminder.Alert_Recipient_6_From_Level__c <= approvalLevel
                && approvalProcessReminder.Additional_Recipient_6__c != null){
                return approvalProcessReminder.Additional_Recipient_6__c;
            }
            
            return null;
        }
    }
    
    //Wrap the standard salesfore ProcessInstance/InstanceItems
    public class ProcessInstanceRecord{
        
        public String id;
        public String status;
        public String targetObjectId;
        public DateTime lastModifiedDate;
        
        public list<ProcessInstanceItemRecord> items;
        
        public ProcessInstanceRecord(String pId, String pStatus, String pTargetObjectId, DateTime pDateTime){
            id = pId;
            status = pStatus;
            targetObjectId = pTargetObjectId;
            lastModifiedDate = pDateTime;
            
            items = new list<ProcessInstanceItemRecord>();
        }
        
        public void addItem(ProcessInstanceItemRecord itemRecord){
            items.add(itemRecord);
        }
    }
    
    
    public class ProcessInstanceItemRecord{
        public String actorId;
        public String stepStatus;
        public DateTime createdDate;
        
        public ProcessInstanceItemRecord(String pActorId, String pStepStatus, Datetime pCreatedDate){
            actorId = pActorId;
            stepStatus = pStepStatus;
            createdDate = pCreatedDate;
        }
    }
    
    
    //###########################################
    //### Schedule job to run
    //###########################################   
    webservice static String scheduleProcess(){
        String retMsg;
        
        try{
            list<CronTrigger> l_cr = [SELECT id, CronExpression, TimesTriggered, CronJobDetail.Name FROM CronTrigger WHERE CronJobDetail.Name = 'ApprovalProcessReminders' limit 1];
        
            if(l_cr.isEmpty()){
                String jobID = system.schedule('ApprovalProcessReminders', '0 0 * ? * *', new ScheduleApprovalReminders());

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
    webservice static String abortProcess(){
        string retMsg;
        try{
            list<CronTrigger> l_cr = [SELECT id, CronExpression, TimesTriggered, CronJobDetail.Name FROM CronTrigger WHERE CronJobDetail.Name = 'ApprovalProcessReminders' limit 1];
        
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
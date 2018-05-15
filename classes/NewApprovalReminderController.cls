public class NewApprovalReminderController{

    public Approval_Process_Reminder__c approvalReminders {get; set;}
    
    public list<SelectOption> approvalProcessOptions {get; set;}
    public list<SelectOption> userOptions {get; set;}
    
    public map <String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
    
    public ProcessDefinition aprProcess;
    
    public NewApprovalReminderController(ApexPages.StandardController sc){
    
        String recordId = (String) sc.getRecord().Id;
        
        
        //Get current approval process reminders, to prevent 2 setup for same approval
        set<String> s_existsSetup = new set<String>();
        for(Approval_Process_Reminder__c setupRecord : [select Related_Approval_Process__c from Approval_Process_Reminder__c ]){
            s_existsSetup.add(setupRecord.Related_Approval_Process__c);
        }
        
        approvalProcessOptions = new list<SelectOption>();
        userOptions = new list<SelectOption>();
        
        approvalProcessOptions.add(new SelectOption('None', 'None'));
        
        for(ProcessDefinition appProcess :     [select id, Name, DeveloperName,State,Type,TableEnumOrId 
                                                from ProcessDefinition 
                                                where state = 'Active' and type='Approval']){
            
            if(! s_existsSetup.contains(appProcess.DeveloperName)){
            
                approvalProcessOptions.add(new SelectOption(appProcess.DeveloperName, appProcess.Name));
            }
        }
        
        if(recordId == null){
            approvalReminders = new Approval_Process_Reminder__c (Alert_Recipient_1_From_Level__c = 1, Alert_Recipient_2_From_Level__c = 1,
                Alert_Recipient_3_From_Level__c = 1, Alert_Recipient_4_From_Level__c = 1, Alert_Recipient_5_From_Level__c = 1, Alert_Recipient_6_From_Level__c = 1);
        }
        else{
            approvalReminders = [   select Id, Name, Active__c, Related_Object__c, Reminder_After__c, Business_Hours__c, Related_Approval_Process__c,
                                        Additional_Recipient_1__c, Additional_Recipient_2__c, Additional_Recipient_3__c, Additional_Recipient_4__c, 
                                        Additional_Recipient_5__c, Additional_Recipient_6__c, Alert_Recipient_1_From_Level__c, Alert_Recipient_2_From_Level__c,
                                        Alert_Recipient_3_From_Level__c, Alert_Recipient_4_From_Level__c, Alert_Recipient_5_From_Level__c,
                                        Alert_Recipient_6_From_Level__c
                                    from Approval_Process_Reminder__c where Id = :recordId];
        
             fetchObjectUsers();
        }
    }
    
    public PageReference fetchObjectUsers(){
    
        if(approvalReminders.Related_Approval_Process__c != null && approvalReminders.Related_Approval_Process__c != 'None'){
            aprProcess = [select id, TableEnumOrId from ProcessDefinition where DeveloperName = :approvalReminders.Related_Approval_Process__c];
        
        
            userOptions = new list<SelectOption>();
            userOptions.add(new SelectOption('None', 'None'));
            
            approvalReminders.Related_Object__c = aprProcess.TableEnumOrId;
        
            for(Schema.SObjectField field : schemaMap.get(aprProcess.TableEnumOrId).getDescribe().fields.getMap().values()){
                Schema.DescribeFieldResult dr  = field.getDescribe();
                
                if(dr.getType() == DisplayType.Reference && dr.getReferenceTo()[0].getDescribe().getName() == 'User'){
                    userOptions.add(new SelectOption(dr.getName(), dr.getLabel()));
                }
            }
        }
        
        return null;
    }
    
    public PageReference saveRecord(){
        try{
            upsert approvalReminders;
        }
        catch(Exception ex){
            apexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR, ex.getMessage()));
                
            return null;
        }
        
        return new PageReference('/' + approvalReminders.Id);
    }
}
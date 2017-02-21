trigger ApprovalProcessReminderTrigger on Approval_Process_Reminder__c (before insert, before update) {
    
    map <String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
 
 
    for(Approval_Process_Reminder__c apr : trigger.new){
        
        //Validate the Object Name
        if((trigger.isInsert)
            || (trigger.isUpdate && apr.Related_Object__c != trigger.oldMap.get(apr.id).Related_Object__c)){
                
            if(! schemaMap.containsKey(apr.Related_Object__c)){
                apr.addError('Invalid object name: ' + apr.Related_Object__c);
            }
        }
        
        //Validate additional recipients fields
        if((trigger.isInsert)
                || (trigger.isUpdate && 
                        (apr.Additional_Recipient_1__c != trigger.oldMap.get(apr.id).Additional_Recipient_1__c
                        || apr.Additional_Recipient_2__c != trigger.oldMap.get(apr.id).Additional_Recipient_2__c))){
                    
            if(schemaMap.containsKey(apr.Related_Object__c)){
                
                
                
                if(apr.Additional_Recipient_1__c != null){
                   if(apr.Additional_Recipient_1__c.startsWith('User')){
                        if(! schemaMap.get('User').getDescribe().fields.getMap().containsKey(apr.Additional_Recipient_1__c.subStringAfter('User.'))){
                        
                            apr.addError('Invalid field for User Object:' + apr.Additional_Recipient_1__c + '.');
                        }
                    }
                    else{
                        if(! schemaMap.get(apr.Related_Object__c).getDescribe().fields.getMap().containsKey(apr.Additional_Recipient_1__c)){
                            apr.addError('Invalid field for object:' + apr.Additional_Recipient_1__c + '.');
                        }
                    }
                }
                
                if(apr.Additional_Recipient_2__c != null){
                    if(apr.Additional_Recipient_2__c.startsWith('User')){
                        if (! schemaMap.get('User').getDescribe().fields.getMap().containsKey(apr.Additional_Recipient_2__c.subStringAfter('User.'))){
                        
                            apr.addError('Invalid field for User Object:' + apr.Additional_Recipient_2__c + '.');    
                         }
                    }
                    else{
                        if(! schemaMap.get(apr.Related_Object__c).getDescribe().fields.getMap().containsKey(apr.Additional_Recipient_2__c)){
                            apr.addError('Invalid field for object:' + apr.Additional_Recipient_2__c + '.');
                        }
                    }
                }
            }
        }
    }   
}

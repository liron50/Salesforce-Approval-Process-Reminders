global class ScheduleApprovalReminders implements Schedulable {
    
    global void execute(SchedulableContext sc){
        
         Database.executeBatch(new BatchApprovalReminders(), 10);
    }
    
}
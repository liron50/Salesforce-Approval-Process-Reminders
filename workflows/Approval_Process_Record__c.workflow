<?xml version="1.0" encoding="UTF-8"?>
<Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
    <alerts>
        <fullName>Email_Alert_Approval_Process_Reminder</fullName>
        <description>Email Alert - Approval Process Reminder</description>
        <protected>false</protected>
        <recipients>
            <field>Additional_Recipient_1__c</field>
            <type>userLookup</type>
        </recipients>
        <recipients>
            <field>Additional_Recipient_2__c</field>
            <type>userLookup</type>
        </recipients>
        <recipients>
            <field>Approver__c</field>
            <type>userLookup</type>
        </recipients>
        <senderType>CurrentUser</senderType>
        <template>unfiled$public/ApprovalProcessReminder</template>
    </alerts>
    <rules>
        <fullName>WF - Approval Process Reminder</fullName>
        <actions>
            <name>Email_Alert_Approval_Process_Reminder</name>
            <type>Alert</type>
        </actions>
        <active>true</active>
        <formula>ISNEW() || ISCHANGED(Alerts_Sent__c)</formula>
        <triggerType>onAllChanges</triggerType>
    </rules>
</Workflow>

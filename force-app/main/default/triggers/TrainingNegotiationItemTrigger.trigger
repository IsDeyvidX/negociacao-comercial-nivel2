trigger TrainingNegotiationItemTrigger on Item_Negociacao__c (
    before insert, before update, before delete,
    after insert, after update, after delete, after undelete
) {
    TrainingNegotiationItemHandler.run();
}

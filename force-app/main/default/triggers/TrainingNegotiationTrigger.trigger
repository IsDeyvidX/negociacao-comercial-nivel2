trigger TrainingNegotiationTrigger on Negociacao_Comercial__c (before insert, before update, before delete) {
    TrainingNegotiationHandler.run();
}

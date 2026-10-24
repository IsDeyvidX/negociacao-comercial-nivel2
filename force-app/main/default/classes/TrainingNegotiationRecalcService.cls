/**
 * Recalcula o Valor Bruto dos pais a partir da soma dos subtotais dos itens.
 * Bulkificado: 1 agregacao + 1 consulta + 1 DML para qualquer quantidade de pais.
 * "without sharing": e uma regra de integridade do sistema, independente de quem alterou o item.
 */
public without sharing class TrainingNegotiationRecalcService {

    public static void recalculate(Set<Id> parentIds) {
        if (parentIds == null || parentIds.isEmpty()) {
            return;
        }

        Map<Id, Decimal> totals = new Map<Id, Decimal>();
        for (AggregateResult row : [
            SELECT Negociacao__c parentId, SUM(Subtotal__c) total
            FROM Item_Negociacao__c WHERE Negociacao__c IN :parentIds GROUP BY Negociacao__c
        ]) {
            Decimal total = (Decimal) row.get('total');
            totals.put((Id) row.get('parentId'), total == null ? 0 : total);
        }

        // Consulta os pais para ignorar os que nao existem mais (ex.: exclusao em cascata do pai).
        List<Negociacao_Comercial__c> toUpdate = new List<Negociacao_Comercial__c>();
        for (Negociacao_Comercial__c parent : [SELECT Id, Valor_Bruto__c FROM Negociacao_Comercial__c WHERE Id IN :parentIds]) {
            Decimal newValue = totals.containsKey(parent.Id) ? totals.get(parent.Id).setScale(2, RoundingMode.HALF_UP) : 0;
            if (parent.Valor_Bruto__c != newValue) {
                toUpdate.add(new Negociacao_Comercial__c(Id = parent.Id, Valor_Bruto__c = newValue));
            }
        }
        if (toUpdate.isEmpty()) {
            return;
        }

        Boolean previous = TrainingNegotiationContext.isRecalculating();
        TrainingNegotiationContext.setRecalculating(true);
        try {
            List<Database.SaveResult> results = Database.update(toUpdate, false);
            for (Integer i = 0; i < results.size(); i++) {
                if (results[i].isSuccess()) {
                    continue;
                }
                Database.Error error = results[i].getErrors()[0];
                if (error.getStatusCode() == StatusCode.ENTITY_IS_DELETED) {
                    continue;
                }
                throw new TrainingException(error.getMessage());
            }
        } finally {
            TrainingNegotiationContext.setRecalculating(previous);
        }
    }
}

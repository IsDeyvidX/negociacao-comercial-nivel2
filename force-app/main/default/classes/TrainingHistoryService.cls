/**
 * Grava a trilha de auditoria (Historico_Decisao__c).
 * "without sharing" de proposito: o historico e gravado em modo sistema para que nenhum
 * usuario (nem o vendedor) consiga forjar ou apagar eventos pela API; os usuarios so tem LEITURA.
 */
public without sharing class TrainingHistoryService {

    public static Historico_Decisao__c build(Negociacao_Comercial__c negotiation, String evento, String statusAnterior,
                                             String statusNovo, String motivo, Id aprovadorEsperado, String origem) {
        return new Historico_Decisao__c(
            Negociacao__c = negotiation.Id,
            Ciclo__c = negotiation.Ciclo_Aprovacao__c,
            Decisao__c = evento,
            Status_Anterior__c = statusAnterior,
            Status_Novo__c = statusNovo,
            Nivel_Aprovacao__c = negotiation.Nivel_Aprovacao__c,
            Motivo__c = motivo,
            Aprovador_Esperado__c = aprovadorEsperado,
            Usuario__c = UserInfo.getUserId(),
            Data_Hora__c = System.now(),
            Origem__c = origem
        );
    }

    public static void save(List<Historico_Decisao__c> rows) {
        if (rows != null && !rows.isEmpty()) {
            insert rows;
        }
    }
}

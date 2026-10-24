/**
 * Acao Apex reutilizavel (Screen Flow "Negociacao_Decisao_Aprovacao" ou qualquer outro chamador).
 * Nunca lanca excecao para o Flow: devolve success/message amigaveis (sem stack trace).
 */
public with sharing class TrainingApprovalDecisionAction {

    public class Request {
        @InvocableVariable(required=true label='Id da negociação')
        public Id negotiationId;
        @InvocableVariable(required=true label='Decisão (Aprovada ou Rejeitada)')
        public String decisao;
        @InvocableVariable(label='Motivo (obrigatório na rejeição)')
        public String motivo;
    }

    public class Result {
        @InvocableVariable(label='Sucesso')
        public Boolean success;
        @InvocableVariable(label='Mensagem')
        public String message;
    }

    @InvocableMethod(label='Training - Aplicar decisão de aprovação' description='Valida autorização no servidor e aplica a decisão.')
    public static List<Result> apply(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request request : requests) {
            Result result = new Result();
            try {
                TrainingApprovalService.DecisionResult decision =
                    TrainingApprovalService.decide(request.negotiationId, request.decisao, request.motivo);
                result.success = decision.success;
                result.message = decision.message;
            } catch (Exception e) {
                result.success = false;
                result.message = TrainingNegotiationService.friendlyMessage(e);
            }
            results.add(result);
        }
        return results;
    }
}

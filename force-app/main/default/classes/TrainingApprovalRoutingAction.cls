/**
 * Acao Apex chamada pelo Record-Triggered Flow "Negociacao_Roteamento_Aprovacao".
 * O Flow decide O QUE fazer (matriz/tarefa); o Apex resolve quem aprova e executa a aprovacao automatica
 * com a validacao de contexto exigida pela Trigger.
 */
public with sharing class TrainingApprovalRoutingAction {

    public class Request {
        @InvocableVariable(required=true label='Id da negociação')
        public Id negotiationId;
        @InvocableVariable(required=true label='Nível de aprovação')
        public String nivel;
        @InvocableVariable(label='Aprovação automática?')
        public Boolean autoApprove;
    }

    public class Result {
        @InvocableVariable(label='Id do aprovador')
        public Id approverId;
        @InvocableVariable(label='Aprovada automaticamente?')
        public Boolean autoApproved;
    }

    @InvocableMethod(label='Training - Rotear negociação' description='Resolve o aprovador do nível ou aprova automaticamente.')
    public static List<Result> route(List<Request> requests) {
        List<Result> results = new List<Result>();
        List<Id> autoIds = new List<Id>();
        Map<String, Id> approverByLevel = new Map<String, Id>();
        Map<Id, Id> approverByNegotiation = new Map<Id, Id>();

        for (Request request : requests) {
            Result result = new Result();
            if (request.autoApprove == true) {
                autoIds.add(request.negotiationId);
                result.autoApproved = true;
            } else {
                if (!approverByLevel.containsKey(request.nivel)) {
                    approverByLevel.put(request.nivel, TrainingApproverResolver.resolve(request.nivel));
                }
                result.approverId = approverByLevel.get(request.nivel);
                result.autoApproved = false;
                approverByNegotiation.put(request.negotiationId, result.approverId);
            }
            results.add(result);
        }

        TrainingApprovalService.autoApprove(autoIds);
        TrainingApprovalService.logRouting(approverByNegotiation);
        return results;
    }
}

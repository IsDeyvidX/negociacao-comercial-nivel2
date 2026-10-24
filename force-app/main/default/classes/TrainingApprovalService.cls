/**
 * Decisao de aprovacao (US-04) e aprovacao automatica (US-03).
 *
 * Seguranca: a autorizacao NAO depende da UI/FlexiPage. A Custom Permission do nivel e validada aqui,
 * no servidor, para qualquer chamada (Screen Flow, Apex direto, Execute Anonymous).
 * Concorrencia: lock de linha (FOR UPDATE) + checagem de status => apenas uma decisao valida por ciclo.
 */
public with sharing class TrainingApprovalService {

    public class DecisionResult {
        public Boolean success;
        public String message;
        public String status;
    }

    /** O usuario atual possui a Custom Permission do nivel informado? */
    public static Boolean hasLevelPermission(String nivel) {
        if (String.isBlank(nivel)) {
            return false;
        }
        Aprovacao_Nivel__mdt cfg = TrainingApprovalMatrix.byNivel(nivel);
        if (cfg == null || cfg.Aprovacao_Automatica__c == true || String.isBlank(cfg.Custom_Permission__c)) {
            return false;
        }
        return FeatureManagement.checkPermission(cfg.Custom_Permission__c);
    }

    public static DecisionResult decide(Id negotiationId, String decision, String reason) {
        if (decision != TrainingConstants.APROVADA && decision != TrainingConstants.REJEITADA) {
            throw new TrainingException('Decisão inválida. Use Aprovada ou Rejeitada.');
        }
        if (decision == TrainingConstants.REJEITADA && String.isBlank(reason)) {
            throw new TrainingException('Informe o motivo da rejeição.');
        }
        if (!Schema.sObjectType.Negociacao_Comercial__c.isAccessible()) {
            throw new TrainingException('Você não tem acesso às negociações.');
        }

        Savepoint sp = Database.setSavepoint();
        try {
            Negociacao_Comercial__c negotiation = TrainingNegotiationService.lock(negotiationId);

            if (negotiation.Status__c != TrainingConstants.PENDENTE) {
                throw new TrainingException('Esta negociação já foi resolvida (status atual: ' + negotiation.Status__c
                    + '). Nenhuma nova decisão foi aplicada.');
            }
            if (!hasLevelPermission(negotiation.Nivel_Aprovacao__c)) {
                throw new TrainingException('Você não tem permissão para decidir negociações do nível ' + negotiation.Nivel_Aprovacao__c + '.');
            }

            Id expectedApprover = negotiation.Aprovador__c;
            String cleanReason = decision == TrainingConstants.REJEITADA ? reason.trim() : null;

            Boolean previous = TrainingNegotiationContext.isDecisionAuthorized();
            TrainingNegotiationContext.setDecisionAuthorized(true);
            try {
                update as user new Negociacao_Comercial__c(
                    Id = negotiation.Id,
                    Status__c = decision,
                    Aprovador__c = UserInfo.getUserId(),
                    Data_Aprovacao__c = System.now(),
                    Motivo_Rejeicao__c = cleanReason
                );
            } finally {
                TrainingNegotiationContext.setDecisionAuthorized(previous);
            }

            TrainingHistoryService.save(new List<Historico_Decisao__c>{
                TrainingHistoryService.build(negotiation, decision, TrainingConstants.PENDENTE, decision, cleanReason,
                    expectedApprover, 'Screen Flow / serviço de decisão')
            });
            closeApprovalTasks(negotiation.Id);

            DecisionResult result = new DecisionResult();
            result.success = true;
            result.status = decision;
            result.message = 'Negociação ' + negotiation.Name + (decision == TrainingConstants.APROVADA ? ' aprovada' : ' rejeitada') + ' com sucesso.';
            return result;
        } catch (Exception e) {
            Database.rollback(sp);
            throw e;
        }
    }

    /** Aprovacao automatica (0% a 5%): transicao Pendente -> Aprovada com historico. Idempotente. */
    public static void autoApprove(List<Id> negotiationIds) {
        if (negotiationIds == null || negotiationIds.isEmpty()) {
            return;
        }
        List<Negociacao_Comercial__c> rows = [
            SELECT Id, Name, Status__c, Nivel_Aprovacao__c, Ciclo_Aprovacao__c
            FROM Negociacao_Comercial__c WHERE Id IN :negotiationIds FOR UPDATE
        ];
        List<Negociacao_Comercial__c> updates = new List<Negociacao_Comercial__c>();
        List<Historico_Decisao__c> history = new List<Historico_Decisao__c>();
        for (Negociacao_Comercial__c n : rows) {
            if (n.Status__c != TrainingConstants.PENDENTE) {
                continue;   // reprocessamento: ja resolvida, nada a fazer
            }
            if (n.Nivel_Aprovacao__c != TrainingConstants.NIVEL_AUTOMATICA) {
                throw new TrainingException('A negociação ' + n.Name + ' não é elegível à aprovação automática.');
            }
            updates.add(new Negociacao_Comercial__c(Id = n.Id, Status__c = TrainingConstants.APROVADA, Data_Aprovacao__c = System.now()));
            history.add(TrainingHistoryService.build(n, 'Aprovada automaticamente', TrainingConstants.PENDENTE,
                TrainingConstants.APROVADA, null, null, 'Flow: roteamento'));
        }
        if (updates.isEmpty()) {
            return;
        }
        Boolean previous = TrainingNegotiationContext.isDecisionAuthorized();
        TrainingNegotiationContext.setDecisionAuthorized(true);
        try {
            update updates;   // modo sistema: e o proprio sistema aprovando, nao o usuario
        } finally {
            TrainingNegotiationContext.setDecisionAuthorized(previous);
        }
        TrainingHistoryService.save(history);
    }

    /** Historico "Submetida" para negociacoes roteadas a um aprovador humano. */
    public static void logRouting(Map<Id, Id> approverByNegotiation) {
        if (approverByNegotiation == null || approverByNegotiation.isEmpty()) {
            return;
        }
        List<Historico_Decisao__c> history = new List<Historico_Decisao__c>();
        for (Negociacao_Comercial__c n : [
            SELECT Id, Name, Status__c, Nivel_Aprovacao__c, Ciclo_Aprovacao__c
            FROM Negociacao_Comercial__c WHERE Id IN :approverByNegotiation.keySet()
        ]) {
            history.add(TrainingHistoryService.build(n, 'Submetida', TrainingConstants.RASCUNHO, TrainingConstants.PENDENTE,
                null, approverByNegotiation.get(n.Id), 'Flow: roteamento'));
        }
        TrainingHistoryService.save(history);
    }

    /** Conclui as tarefas de aprovacao abertas (best effort: nao derruba a decisao se alguma falhar). */
    public static void closeApprovalTasks(Id negotiationId) {
        new TaskCloser().close(negotiationId);
    }

    /**
     * "without sharing" de proposito: concluir a tarefa do ciclo e bookkeeping do sistema apos uma decisao
     * ja validada; o decisor pode nao ser o dono da tarefa (ex.: outro usuario com a mesma permissao).
     */
    private without sharing class TaskCloser {
        public void close(Id negotiationId) {
            List<Task> tasks = [SELECT Id FROM Task WHERE WhatId = :negotiationId AND IsClosed = false AND Chave_Idempotencia__c != null];
            for (Task t : tasks) {
                t.Status = 'Completed';
            }
            if (!tasks.isEmpty()) {
                Database.update(tasks, false);
            }
        }
    }
}

/**
 * Regras transacionais da negociacao feitas pelo vendedor: catalogo, salvar (com reprecificacao no servidor),
 * submeter, reabrir e cancelar. Roda "with sharing" e faz DML em modo usuario (CRUD/FLS aplicados).
 * O Controller e fino: so traduz excecoes para AuraHandledException.
 */
public with sharing class TrainingNegotiationService {

    // ------------------------------------------------------------------ DTOs de saida (LWC)
    public class CatalogItem {
        @AuraEnabled public Id productId;
        @AuraEnabled public String productName;
        @AuraEnabled public String productCode;
        @AuraEnabled public Decimal unitPrice;
    }

    public class DraftItem {
        @AuraEnabled public Id productId;
        @AuraEnabled public Integer quantity;
    }

    public class Draft {
        @AuraEnabled public Id negotiationId;
        @AuraEnabled public Decimal discountPercent = 0;
        @AuraEnabled public String justification;
        @AuraEnabled public List<DraftItem> items = new List<DraftItem>();
    }

    public class MatrixLevel {
        @AuraEnabled public String nivel;
        @AuraEnabled public Decimal minimo;
        @AuraEnabled public Decimal maximo;
        @AuraEnabled public Boolean automatica;
    }

    public class SaveResult {
        @AuraEnabled public Id negotiationId;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String approvalLevel;
        @AuraEnabled public Decimal grossValue;
        @AuraEnabled public Decimal discountPercent;
        @AuraEnabled public Decimal discountValue;
        @AuraEnabled public Decimal finalValue;
        @AuraEnabled public Boolean submitted;
        @AuraEnabled public String message;
    }

    public class ItemView {
        @AuraEnabled public Id id;
        @AuraEnabled public String productName;
        @AuraEnabled public String productCode;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Decimal subtotal;
    }

    public class NegotiationView {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String approvalLevel;
        @AuraEnabled public Integer cycle;
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public String opportunityName;
        @AuraEnabled public Decimal grossValue;
        @AuraEnabled public Decimal discountPercent;
        @AuraEnabled public Decimal discountValue;
        @AuraEnabled public Decimal finalValue;
        @AuraEnabled public String justification;
        @AuraEnabled public String rejectionReason;
        @AuraEnabled public Id approverId;
        @AuraEnabled public String approverName;
        @AuraEnabled public Datetime decisionDate;
        @AuraEnabled public Boolean canDecide;
        @AuraEnabled public Boolean canGenerateOrder;
        @AuraEnabled public Id orderId;
        @AuraEnabled public String orderNumber;
        @AuraEnabled public List<ItemView> items = new List<ItemView>();
    }

    // ------------------------------------------------------------------ consultas auxiliares
    public static Opportunity loadOpportunity(Id opportunityId) {
        if (opportunityId == null) {
            throw new TrainingException('Oportunidade não informada.');
        }
        List<Opportunity> rows = [SELECT Id, Name, AccountId, Pricebook2Id FROM Opportunity WHERE Id = :opportunityId WITH USER_MODE];
        if (rows.isEmpty()) {
            throw new TrainingException('Oportunidade não encontrada ou sem acesso.');
        }
        return rows[0];
    }

    /** Pricebook da Opportunity; sem ele, usa o Pricebook standard (consultado, nunca hardcoded). */
    public static Id resolvePricebookId(Id opportunityPricebookId) {
        if (opportunityPricebookId != null) {
            return opportunityPricebookId;
        }
        List<Pricebook2> standard = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
        if (standard.isEmpty()) {
            throw new TrainingException('Nenhum Pricebook válido foi encontrado para esta oportunidade.');
        }
        return standard[0].Id;
    }

    /** Le a negociacao COM lock de linha (FOR UPDATE). Serializa decisoes/geracoes concorrentes. */
    public static Negociacao_Comercial__c lock(Id negotiationId) {
        if (negotiationId == null) {
            throw new TrainingException('Negociação não informada.');
        }
        List<Negociacao_Comercial__c> rows = [
            SELECT Id, Name, Status__c, Nivel_Aprovacao__c, Ciclo_Aprovacao__c, Aprovador__c, Opportunity__c,
                   Percentual_Desconto__c, Valor_Final__c
            FROM Negociacao_Comercial__c WHERE Id = :negotiationId FOR UPDATE
        ];
        if (rows.isEmpty()) {
            throw new TrainingException('Negociação não encontrada ou sem acesso.');
        }
        return rows[0];
    }

    private static Negociacao_Comercial__c queryFull(Id negotiationId) {
        List<Negociacao_Comercial__c> rows = [
            SELECT Id, Name, Status__c, Nivel_Aprovacao__c, Ciclo_Aprovacao__c, Opportunity__c, Opportunity__r.Name,
                   Valor_Bruto__c, Percentual_Desconto__c, Valor_Desconto__c, Valor_Final__c, Justificativa__c,
                   Motivo_Rejeicao__c, Data_Aprovacao__c, Aprovador__c, Aprovador__r.Name
            FROM Negociacao_Comercial__c WHERE Id = :negotiationId WITH USER_MODE
        ];
        if (rows.isEmpty()) {
            throw new TrainingException('Negociação não encontrada ou sem acesso.');
        }
        return rows[0];
    }

    public static List<CatalogItem> getCatalog(Id opportunityId) {
        if (!Schema.sObjectType.Product2.isAccessible()) {
            throw new TrainingException('Você não tem acesso ao catálogo de produtos.');
        }
        Opportunity opp = loadOpportunity(opportunityId);
        Id pricebookId = resolvePricebookId(opp.Pricebook2Id);
        List<CatalogItem> result = new List<CatalogItem>();
        for (PricebookEntry entry : [
            SELECT Product2Id, Product2.Name, Product2.ProductCode, UnitPrice
            FROM PricebookEntry
            WHERE Pricebook2Id = :pricebookId AND IsActive = true AND Product2.IsActive = true AND UnitPrice > 0
            ORDER BY Product2.Name LIMIT 500
        ]) {
            CatalogItem item = new CatalogItem();
            item.productId = entry.Product2Id;
            item.productName = entry.Product2.Name;
            item.productCode = entry.Product2.ProductCode;
            item.unitPrice = entry.UnitPrice;
            result.add(item);
        }
        return result;
    }

    public static List<MatrixLevel> getApprovalMatrix() {
        List<MatrixLevel> levels = new List<MatrixLevel>();
        for (Aprovacao_Nivel__mdt cfg : TrainingApprovalMatrix.allLevels()) {
            MatrixLevel level = new MatrixLevel();
            level.nivel = cfg.Nivel__c;
            level.minimo = cfg.Percentual_Minimo__c;
            level.maximo = cfg.Percentual_Maximo__c;
            level.automatica = cfg.Aprovacao_Automatica__c;
            levels.add(level);
        }
        return levels;
    }

    public static Draft getDraft(Id opportunityId, Id negotiationId) {
        Draft draft = new Draft();
        Negociacao_Comercial__c negotiation = null;
        String rascunho = TrainingConstants.RASCUNHO;
        if (negotiationId != null) {
            negotiation = queryFull(negotiationId);
            if (negotiation.Status__c != TrainingConstants.RASCUNHO && negotiation.Status__c != TrainingConstants.REJEITADA) {
                throw new TrainingException('Somente negociações em Rascunho ou Rejeitada podem ser editadas.');
            }
        } else if (opportunityId != null) {
            List<Negociacao_Comercial__c> rows = [
                SELECT Id, Percentual_Desconto__c, Justificativa__c, Status__c
                FROM Negociacao_Comercial__c
                WHERE Opportunity__c = :opportunityId AND Status__c = :rascunho
                WITH USER_MODE ORDER BY CreatedDate DESC LIMIT 1
            ];
            if (!rows.isEmpty()) {
                negotiation = rows[0];
            }
        }
        if (negotiation == null) {
            return draft;
        }
        draft.negotiationId = negotiation.Id;
        draft.discountPercent = negotiation.Percentual_Desconto__c == null ? 0 : negotiation.Percentual_Desconto__c;
        draft.justification = negotiation.Justificativa__c;
        for (Item_Negociacao__c item : [
            SELECT Produto__c, Quantidade__c FROM Item_Negociacao__c
            WHERE Negociacao__c = :negotiation.Id WITH USER_MODE ORDER BY CreatedDate, Id
        ]) {
            DraftItem di = new DraftItem();
            di.productId = item.Produto__c;
            di.quantity = item.Quantidade__c == null ? null : item.Quantidade__c.intValue();
            draft.items.add(di);
        }
        return draft;
    }

    // ------------------------------------------------------------------ salvar (US-01)
    public static SaveResult saveNegotiation(TrainingNegotiationRequest request, Boolean submit) {
        if (request == null || request.items == null || request.items.isEmpty()) {
            throw new TrainingException('Adicione ao menos um produto à negociação.');
        }
        if (!Schema.sObjectType.Negociacao_Comercial__c.isCreateable() || !Schema.sObjectType.Item_Negociacao__c.isCreateable()) {
            throw new TrainingException('Você não tem permissão para criar ou editar negociações.');
        }
        if (!Schema.sObjectType.Product2.isAccessible()) {
            throw new TrainingException('Você não tem acesso ao catálogo de produtos.');
        }

        Decimal pct = request.discountPercent == null ? 0 : request.discountPercent;
        if (pct < 0 || pct > TrainingConstants.DESCONTO_MAXIMO) {
            throw new TrainingException('O percentual de desconto deve estar entre 0% e 30%.');
        }
        pct = pct.setScale(2, RoundingMode.HALF_UP);

        Set<Id> productIds = new Set<Id>();
        for (TrainingNegotiationRequest.Item item : request.items) {
            if (item == null || item.productId == null) {
                throw new TrainingException('Selecione o produto de todos os itens.');
            }
            if (item.quantity == null || item.quantity < 1) {
                throw new TrainingException('A quantidade de cada item deve ser um número inteiro maior ou igual a 1.');
            }
            if (!productIds.add(item.productId)) {
                throw new TrainingException('Não é permitido repetir o mesmo produto na negociação.');
            }
        }

        Savepoint sp = Database.setSavepoint();
        try {
            Negociacao_Comercial__c existing = null;
            Id opportunityId = request.opportunityId;
            if (request.negotiationId != null) {
                existing = lock(request.negotiationId);
                if (opportunityId != null && opportunityId != existing.Opportunity__c) {
                    throw new TrainingException('A negociação informada pertence a outra oportunidade.');
                }
                opportunityId = existing.Opportunity__c;
                if (existing.Status__c != TrainingConstants.RASCUNHO && existing.Status__c != TrainingConstants.REJEITADA) {
                    throw new TrainingException('Somente negociações em Rascunho ou Rejeitada podem ser editadas.');
                }
            }
            Opportunity opp = loadOpportunity(opportunityId);

            // Reprecificacao no servidor: o preco SEMPRE vem do PricebookEntry, nunca do navegador.
            Id pricebookId = resolvePricebookId(opp.Pricebook2Id);
            Map<Id, PricebookEntry> entries = new Map<Id, PricebookEntry>();
            for (PricebookEntry entry : [
                SELECT Id, Product2Id, UnitPrice FROM PricebookEntry
                WHERE Pricebook2Id = :pricebookId AND Product2Id IN :productIds AND IsActive = true AND Product2.IsActive = true
            ]) {
                entries.put(entry.Product2Id, entry);
            }
            if (entries.size() != productIds.size()) {
                List<String> missing = new List<String>();
                for (Product2 p : [SELECT Name FROM Product2 WHERE Id IN :productIds]) {
                    if (!entries.containsKey(p.Id)) {
                        missing.add(p.Name);
                    }
                }
                throw new TrainingException('Produto(s) fora do catálogo válido desta oportunidade: ' + String.join(missing, ', ') + '.');
            }

            Negociacao_Comercial__c negotiation;
            if (existing == null) {
                negotiation = new Negociacao_Comercial__c(
                    Opportunity__c = opportunityId, Percentual_Desconto__c = pct,
                    Justificativa__c = request.justification, Status__c = TrainingConstants.RASCUNHO
                );
                insert as user negotiation;
            } else {
                if (existing.Status__c == TrainingConstants.REJEITADA) {
                    reopenInternal(existing);
                }
                negotiation = new Negociacao_Comercial__c(
                    Id = existing.Id, Percentual_Desconto__c = pct, Justificativa__c = request.justification
                );
                update as user negotiation;
                List<Item_Negociacao__c> oldItems = [SELECT Id FROM Item_Negociacao__c WHERE Negociacao__c = :negotiation.Id WITH USER_MODE];
                if (!oldItems.isEmpty()) {
                    delete as user oldItems;
                }
            }

            List<Item_Negociacao__c> newItems = new List<Item_Negociacao__c>();
            for (TrainingNegotiationRequest.Item item : request.items) {
                newItems.add(new Item_Negociacao__c(
                    Negociacao__c = negotiation.Id, Produto__c = item.productId,
                    Quantidade__c = item.quantity, Preco_Unitario__c = entries.get(item.productId).UnitPrice
                ));
            }
            insert as user newItems;

            if (submit == true) {
                submitInternal(negotiation.Id);
            }
            return toSaveResult(queryFull(negotiation.Id), submit == true);
        } catch (Exception e) {
            Database.rollback(sp);
            throw e;
        }
    }

    // ------------------------------------------------------------------ transicoes do vendedor
    private static Negociacao_Comercial__c submitInternal(Id negotiationId) {
        Negociacao_Comercial__c negotiation = lock(negotiationId);
        if (negotiation.Status__c != TrainingConstants.RASCUNHO) {
            throw new TrainingException('Somente negociações em Rascunho podem ser enviadas para aprovação. '
                + 'Se foi rejeitada, reabra-a primeiro.');
        }
        update as user new Negociacao_Comercial__c(Id = negotiation.Id, Status__c = TrainingConstants.PENDENTE);
        return negotiation;
    }

    public static SaveResult submitNegotiation(Id negotiationId) {
        submitInternal(negotiationId);
        return toSaveResult(queryFull(negotiationId), true);
    }

    private static void reopenInternal(Negociacao_Comercial__c negotiation) {
        update as user new Negociacao_Comercial__c(Id = negotiation.Id, Status__c = TrainingConstants.RASCUNHO);
        TrainingHistoryService.save(new List<Historico_Decisao__c>{
            TrainingHistoryService.build(negotiation, 'Reaberta para revisão', TrainingConstants.REJEITADA,
                TrainingConstants.RASCUNHO, null, null, 'Serviço de negociação')
        });
    }

    public static SaveResult reopenNegotiation(Id negotiationId) {
        Savepoint sp = Database.setSavepoint();
        try {
            Negociacao_Comercial__c negotiation = lock(negotiationId);
            if (negotiation.Status__c != TrainingConstants.REJEITADA) {
                throw new TrainingException('Somente negociações Rejeitadas podem ser reabertas para revisão.');
            }
            reopenInternal(negotiation);
            return toSaveResult(queryFull(negotiationId), false);
        } catch (Exception e) {
            Database.rollback(sp);
            throw e;
        }
    }

    public static SaveResult cancelNegotiation(Id negotiationId) {
        Savepoint sp = Database.setSavepoint();
        try {
            Negociacao_Comercial__c negotiation = lock(negotiationId);
            if (negotiation.Status__c == TrainingConstants.APROVADA || negotiation.Status__c == TrainingConstants.CANCELADA) {
                throw new TrainingException('Negociações Aprovadas ou Canceladas não podem ser canceladas.');
            }
            String previous = negotiation.Status__c;
            update as user new Negociacao_Comercial__c(Id = negotiation.Id, Status__c = TrainingConstants.CANCELADA);
            TrainingHistoryService.save(new List<Historico_Decisao__c>{
                TrainingHistoryService.build(negotiation, 'Cancelada', previous, TrainingConstants.CANCELADA, null, null, 'Serviço de negociação')
            });
            TrainingApprovalService.closeApprovalTasks(negotiation.Id);
            return toSaveResult(queryFull(negotiationId), false);
        } catch (Exception e) {
            Database.rollback(sp);
            throw e;
        }
    }

    // ------------------------------------------------------------------ visao para a pagina (US-05)
    public static NegotiationView getView(Id negotiationId) {
        Negociacao_Comercial__c n = queryFull(negotiationId);
        NegotiationView view = new NegotiationView();
        view.id = n.Id;
        view.name = n.Name;
        view.status = n.Status__c;
        view.approvalLevel = n.Nivel_Aprovacao__c;
        view.cycle = n.Ciclo_Aprovacao__c == null ? 0 : n.Ciclo_Aprovacao__c.intValue();
        view.opportunityId = n.Opportunity__c;
        view.opportunityName = n.Opportunity__r?.Name;
        view.grossValue = n.Valor_Bruto__c;
        view.discountPercent = n.Percentual_Desconto__c;
        view.discountValue = n.Valor_Desconto__c;
        view.finalValue = n.Valor_Final__c;
        view.justification = n.Justificativa__c;
        view.rejectionReason = n.Motivo_Rejeicao__c;
        view.approverId = n.Aprovador__c;
        view.approverName = n.Aprovador__r?.Name;
        view.decisionDate = n.Data_Aprovacao__c;
        // A UI so recebe um "pode?"; a autorizacao real e reexecutada no servidor em cada acao.
        view.canDecide = n.Status__c == TrainingConstants.PENDENTE && TrainingApprovalService.hasLevelPermission(n.Nivel_Aprovacao__c);

        for (Item_Negociacao__c item : [
            SELECT Id, Produto__r.Name, Produto__r.ProductCode, Quantidade__c, Preco_Unitario__c, Subtotal__c
            FROM Item_Negociacao__c WHERE Negociacao__c = :n.Id WITH USER_MODE ORDER BY CreatedDate, Id
        ]) {
            ItemView iv = new ItemView();
            iv.id = item.Id;
            iv.productName = item.Produto__r?.Name;
            iv.productCode = item.Produto__r?.ProductCode;
            iv.quantity = item.Quantidade__c;
            iv.unitPrice = item.Preco_Unitario__c;
            iv.subtotal = item.Subtotal__c;
            view.items.add(iv);
        }

        view.canGenerateOrder = false;
        if (n.Status__c == TrainingConstants.APROVADA) {
            String key = String.valueOf(n.Id);
            List<Order> orders = [SELECT Id, OrderNumber FROM Order WHERE Negociacao_Origem_Id__c = :key LIMIT 1];
            if (!orders.isEmpty()) {
                view.orderId = orders[0].Id;
                view.orderNumber = orders[0].OrderNumber;
            } else {
                view.canGenerateOrder = Schema.sObjectType.Order.isCreateable();
            }
        }
        return view;
    }

    private static SaveResult toSaveResult(Negociacao_Comercial__c n, Boolean submitted) {
        SaveResult result = new SaveResult();
        result.negotiationId = n.Id;
        result.name = n.Name;
        result.status = n.Status__c;
        result.approvalLevel = n.Nivel_Aprovacao__c;
        result.grossValue = n.Valor_Bruto__c;
        result.discountPercent = n.Percentual_Desconto__c;
        result.discountValue = n.Valor_Desconto__c;
        result.finalValue = n.Valor_Final__c;
        result.submitted = submitted;
        if (n.Status__c == TrainingConstants.APROVADA) {
            result.message = 'Negociação ' + n.Name + ' aprovada automaticamente.';
        } else if (n.Status__c == TrainingConstants.PENDENTE) {
            result.message = 'Negociação ' + n.Name + ' enviada para aprovação (' + n.Nivel_Aprovacao__c + ').';
        } else {
            result.message = 'Negociação ' + n.Name + ' salva (' + n.Status__c + ').';
        }
        return result;
    }

    // ------------------------------------------------------------------ erros amigaveis
    public static String friendlyMessage(Exception e) {
        if (e instanceof TrainingException) {
            return e.getMessage();
        }
        if (e instanceof DmlException) {
            DmlException dml = (DmlException) e;
            if (dml.getNumDml() > 0) {
                if (dml.getDmlType(0) == StatusCode.DUPLICATE_VALUE) {
                    List<String> fields = dml.getDmlFieldNames(0);
                    String detail = dml.getDmlMessage(0);
                    if ((fields != null && fields.contains('Chave_Pendente__c')) || (detail != null && detail.contains('Chave_Pendente'))) {
                        return 'Já existe uma negociação Pendente para esta oportunidade.';
                    }
                    if ((fields != null && fields.contains('Negociacao_Origem_Id__c')) || (detail != null && detail.contains('Negociacao_Origem_Id'))) {
                        return 'Já existe um pedido gerado para esta negociação.';
                    }
                    return 'Registro duplicado: uma solicitação equivalente já foi processada.';
                }
                return dml.getDmlMessage(0);
            }
        }
        System.debug(LoggingLevel.ERROR, 'Training error: ' + e.getTypeName() + ' - ' + e.getMessage() + '\n' + e.getStackTraceString());
        return 'Não foi possível concluir a operação. Tente novamente ou procure o administrador.';
    }

    public static AuraHandledException toAura(Exception e) {
        String message = friendlyMessage(e);
        AuraHandledException ex = new AuraHandledException(message);
        ex.setMessage(message);
        return ex;
    }
}

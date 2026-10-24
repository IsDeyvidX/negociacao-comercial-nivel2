/**
 * Geracao transacional e idempotente de Order + OrderItems (US-06).
 *
 *  - Atomicidade: Savepoint + rollback; qualquer falha desfaz Order e itens parciais.
 *  - Concorrencia/idempotencia: (1) lock de linha da negociacao (FOR UPDATE) e (2) campo unico
 *    Order.Negociacao_Origem_Id__c, que e a "rede de seguranca" no banco caso duas transacoes passem do lock.
 *  - Preco: Pricebook2/PricebookEntry resolvidos por consulta (nunca assume que Product2 basta).
 *  - O desconto da negociacao e distribuido proporcionalmente no UnitPrice de cada OrderItem (HALF_UP, 2 casas).
 */
public with sharing class TrainingOrderService {

    @TestVisible private static Integer testBreakItemIndex;   // somente testes: forca falha no N-esimo item

    public class OrderResult {
        @AuraEnabled public Id orderId;
        @AuraEnabled public String orderNumber;
        @AuraEnabled public Boolean alreadyExisted;
        @AuraEnabled public String message;
    }

    public static OrderResult generateOrder(Id negotiationId) {
        if (negotiationId == null) {
            throw new TrainingException('Negociação não informada.');
        }
        if (!Schema.sObjectType.Order.isCreateable() || !Schema.sObjectType.OrderItem.isCreateable()) {
            throw new TrainingException('Você não tem permissão para gerar pedidos.');
        }

        Savepoint sp = Database.setSavepoint();
        try {
            Negociacao_Comercial__c negotiation = TrainingNegotiationService.lock(negotiationId);
            if (negotiation.Status__c != TrainingConstants.APROVADA) {
                throw new TrainingException('Somente negociações Aprovadas podem gerar pedido (status atual: ' + negotiation.Status__c + ').');
            }

            Order existing = findExistingOrder(negotiation.Id);
            if (existing != null) {
                return existingResult(existing);
            }

            Opportunity opp = TrainingNegotiationService.loadOpportunity(negotiation.Opportunity__c);
            if (opp.AccountId == null) {
                throw new TrainingException('A oportunidade não possui conta; não é possível gerar o pedido.');
            }
            Id pricebookId = TrainingNegotiationService.resolvePricebookId(opp.Pricebook2Id);

            List<Item_Negociacao__c> items = [
                SELECT Id, Produto__c, Produto__r.Name, Quantidade__c, Preco_Unitario__c
                FROM Item_Negociacao__c WHERE Negociacao__c = :negotiation.Id WITH USER_MODE ORDER BY CreatedDate, Id
            ];
            if (items.isEmpty()) {
                throw new TrainingException('A negociação não possui itens.');
            }

            Set<Id> productIds = new Set<Id>();
            for (Item_Negociacao__c item : items) {
                productIds.add(item.Produto__c);
            }
            Map<Id, PricebookEntry> entries = new Map<Id, PricebookEntry>();
            for (PricebookEntry entry : [
                SELECT Id, Product2Id FROM PricebookEntry
                WHERE Pricebook2Id = :pricebookId AND Product2Id IN :productIds AND IsActive = true
            ]) {
                entries.put(entry.Product2Id, entry);
            }
            List<String> missing = new List<String>();
            for (Item_Negociacao__c item : items) {
                if (!entries.containsKey(item.Produto__c)) {
                    missing.add(item.Produto__r.Name);
                }
            }
            if (!missing.isEmpty()) {
                throw new TrainingException('Produto(s) sem entrada ativa no Pricebook da oportunidade: ' + String.join(missing, ', ') + '.');
            }

            Order newOrder = new Order(
                AccountId = opp.AccountId,
                Pricebook2Id = pricebookId,
                EffectiveDate = Date.today(),
                Status = TrainingConstants.STATUS_ORDER_DRAFT,
                Description = 'Gerado a partir da negociação ' + negotiation.Name,
                Negociacao_Comercial__c = negotiation.Id,
                Negociacao_Origem_Id__c = String.valueOf(negotiation.Id),
                Oportunidade_Origem__c = opp.Id
            );
            insert as user newOrder;

            Decimal pct = negotiation.Percentual_Desconto__c == null ? 0 : negotiation.Percentual_Desconto__c;
            Decimal factor = (100 - pct).divide(100, 6);
            List<OrderItem> orderItems = new List<OrderItem>();
            Integer index = 0;
            for (Item_Negociacao__c item : items) {
                OrderItem orderItem = new OrderItem(
                    OrderId = newOrder.Id,
                    PricebookEntryId = entries.get(item.Produto__c).Id,
                    Quantity = item.Quantidade__c,
                    UnitPrice = (item.Preco_Unitario__c * factor).setScale(2, RoundingMode.HALF_UP)
                );
                if (testBreakItemIndex != null && testBreakItemIndex == index) {
                    orderItem.PricebookEntryId = null;   // simula falha no item N
                }
                orderItems.add(orderItem);
                index++;
            }
            insert as user orderItems;

            OrderResult result = new OrderResult();
            result.orderId = newOrder.Id;
            result.alreadyExisted = false;
            result.orderNumber = [SELECT OrderNumber FROM Order WHERE Id = :newOrder.Id].OrderNumber;
            result.message = 'Pedido ' + result.orderNumber + ' gerado com ' + orderItems.size() + ' item(ns).';
            return result;
        } catch (DmlException e) {
            Database.rollback(sp);
            // Corrida: outra transacao criou o pedido primeiro (violacao da chave unica). Devolve o existente.
            if (e.getNumDml() > 0 && e.getDmlType(0) == StatusCode.DUPLICATE_VALUE) {
                Order existing = findExistingOrder(negotiationId);
                if (existing != null) {
                    return existingResult(existing);
                }
            }
            throw new TrainingException('Não foi possível gerar o pedido. Nenhum registro parcial foi mantido. Detalhe: '
                + (e.getNumDml() > 0 ? e.getDmlMessage(0) : e.getMessage()));
        } catch (Exception e) {
            Database.rollback(sp);
            throw e;
        }
    }

    private static Order findExistingOrder(Id negotiationId) {
        String key = String.valueOf(negotiationId);
        List<Order> rows = [SELECT Id, OrderNumber FROM Order WHERE Negociacao_Origem_Id__c = :key LIMIT 1];
        return rows.isEmpty() ? null : rows[0];
    }

    private static OrderResult existingResult(Order existing) {
        OrderResult result = new OrderResult();
        result.orderId = existing.Id;
        result.orderNumber = existing.OrderNumber;
        result.alreadyExisted = true;
        result.message = 'O pedido ' + existing.OrderNumber + ' já havia sido gerado para esta negociação.';
        return result;
    }
}

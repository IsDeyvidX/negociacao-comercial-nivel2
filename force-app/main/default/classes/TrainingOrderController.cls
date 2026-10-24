/**
 * Controller fino da geracao de pedido.
 */
public with sharing class TrainingOrderController {

    @AuraEnabled
    public static TrainingOrderService.OrderResult generateOrder(Id negotiationId) {
        try {
            return TrainingOrderService.generateOrder(negotiationId);
        } catch (Exception e) {
            throw TrainingNegotiationService.toAura(e);
        }
    }
}

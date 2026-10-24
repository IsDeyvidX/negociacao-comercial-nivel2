/**
 * Contexto de transacao compartilhado entre Trigger, Services e Flow-actions.
 *
 * - recalculating: true somente enquanto o RecalcService atualiza o Valor Bruto do pai. Evita
 *   loop de recursao SEM impedir operacoes legitimas (nao e um "ja rodei" booleano global).
 * - decisionAuthorized: true somente dentro do TrainingApprovalService (decisao validada).
 *   A Trigger recusa Pendente -> Aprovada/Rejeitada fora desse caminho (API, Data Loader etc.).
 */
public with sharing class TrainingNegotiationContext {
    private static Boolean recalculating = false;
    private static Boolean decisionAuthorized = false;

    public static Boolean isRecalculating() { return recalculating; }
    public static void setRecalculating(Boolean value) { recalculating = value == true; }

    public static Boolean isDecisionAuthorized() { return decisionAuthorized; }
    public static void setDecisionAuthorized(Boolean value) { decisionAuthorized = value == true; }
}

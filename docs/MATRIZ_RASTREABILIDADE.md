# Rastreabilidade: critérios de aceite → implementação → teste

| Critério | Implementação | Teste |
|---|---|---|
| US-01 CA01 total correto | `TrainingNegotiationService.saveNegotiation` + Trigger de itens | `TrainingNegotiationServiceTest.saveCalculatesTotalsOnServerAndPersists` |
| US-01 CA02 bloqueios | Service + LWC (`validate`) + Trigger | `invalidRequestsAreBlocked`, `itemValidationsBlockInvalidData` |
| US-01 CA03 payload malicioso | DTO sem preço; reprecificação no servidor | `maliciousPayloadDoesNotChangeServerRules` |
| US-01 CA04 persistência | `saveNegotiation` (savepoint) | `saveCalculatesTotals...` |
| US-02 CA01 200 itens | `ItemHandler` + `RecalcService` | `bulk200ItemsRecalculateWithinLimits` |
| US-02 CA02 excluir último | `after delete` → recálculo | `deletingLastItemZeroesTotals` |
| US-02 CA03 troca de pai | `parentIds(new, oldMap)` | `changingParentRecalculatesBothNegotiations` |
| US-02 CA04 aprovada bloqueada | `NegotiationHandler.beforeUpdate` | `approvedNegotiationIsImmutableOnEveryChannel` |
| US-03 CA01 4% automática | Flow + `autoApprove` | `autoApprovalUpToFivePercent` |
| US-03 CA02 12% Pendente + Task | Flow + `ApproverResolver` | `pendingRoutesToDirectorAndDoesNotDuplicateTask` |
| US-03 CA03 sem Task duplicada | `Chave_Idempotencia__c` + critério de entrada | idem |
| US-03 CA04 reenvio = novo ciclo | `Ciclo_Aprovacao__c` | `resubmissionAfterReviewStartsNewCycle` |
| US-04 CA01 sem permissão | `hasLevelPermission` (Custom Permission) | `unauthorizedUsersCannotDecide` |
| US-04 CA02 rejeição sem motivo | Service + Trigger + Flow (campo obrigatório) | `rejectionRequiresReason` |
| US-04 CA03 auditoria | `Historico_Decisao__c` + campos da negociação | `authorizedApproverApproves` |
| US-04 CA04 sem transição duplicada | `FOR UPDATE` + status | `repeatedDecisionDoesNotDuplicateTransition` |
| US-05 CA01–04 | FlexiPage + LWC (ver evidências manuais) | prints (`docs/TESTES_E_EVIDENCIAS.md`) |
| US-06 CA01 3 itens | `TrainingOrderService` | `approvedNegotiationGeneratesOrderWithThreeItems` |
| US-06 CA02 rollback | Savepoint | `failureOnThirdItemRollsBackEverything` |
| US-06 CA03 um Order | `FOR UPDATE` + chave única | `generatingTwiceKeepsASingleOrder`, `existingOrderFromAnotherTransactionIsReused` |
| US-06 CA04 só Aprovada | status | `onlyApprovedNegotiationsGenerateOrders` |
| US-07 CA02 sem privilégio | CRUD/FLS + Custom Permission | `userWithoutPermissionCannotSave`, `controllerReturnsFriendlyErrors...` |
| US-07 CA03 bulk 200 | idem US-02 CA01 | `bulk200ItemsRecalculateWithinLimits` |
| US-07 CA04 sem dados pré-existentes | `TrainingTestDataFactory` | todos |
| Restrição: 1 Pendente por Opportunity | Trigger + `Chave_Pendente__c` única | `onlyOnePendingNegotiationPerOpportunity` |

Matriz mínima do PDF (seção 7): todas as 10 linhas estão cobertas pelos testes acima. A linha "Duas chamadas de decisão concorrentes"
é garantida por `FOR UPDATE` (serialização) e provada pelo comportamento sequencial equivalente em `repeatedDecisionDoesNotDuplicateTransition`
(testes Apex não conseguem disparar duas transações realmente simultâneas).

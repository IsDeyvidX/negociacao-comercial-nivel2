# Roteiro de demonstração (vendedor, aprovador e usuário sem permissão)

Preparação: deploy, Permission Sets atribuídos (vendedor + diretor + um usuário sem nada), `seed-demo.apex` executado.

1. **Vendedor** abre a Opportunity → *Simulador*: adiciona 2 produtos, desconto 4% → prévia → *Salvar e enviar* → página da negociação em **Aprovada** (automática).
2. Na negociação Aprovada: *Gerar pedido* → Order com os itens; clicar de novo mostra "pedido já gerado" (idempotência).
3. Nova negociação com **12%** e justificativa → *Enviar* → **Pendente**, nível Diretor, aprovador esperado visível, Task criada.
4. **Cenário de falha A (vendedor):** na página Pendente o vendedor **não** vê o botão *Decidir*.
5. **Cenário de falha B (usuário sem permissão):** executar no Developer Console como esse usuário:
   `TrainingApprovalService.decide('<id>', 'Aprovada', null);` → "Você não tem permissão...".
6. **Diretor:** *Decidir* → Screen Flow mostra produtos/valores/justificativa/aprovador → tenta **Rejeitar sem motivo** (bloqueado) → rejeita com motivo.
7. Página em **Rejeitada**: motivo visível. Vendedor → *Reabrir para revisão* → edita no simulador → reenvia (ciclo 2, nova Task).
8. Diretor aprova → página **Aprovada**; mostrar o **Histórico de Decisões** (related list) com todos os ciclos.
9. **Cenário de falha C (integridade por API):** Execute Anonymous tentando alterar item/negociação aprovada → erro da Trigger.
10. **Cenário de falha D (concorrência/rollback):** mostrar o teste `failureOnThirdItemRollsBackEverything` e `generatingTwiceKeepsASingleOrder`.

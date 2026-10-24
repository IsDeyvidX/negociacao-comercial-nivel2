/**
 * Constantes do modulo de Negociacao Comercial (evita "magic strings" espalhadas).
 */
public with sharing class TrainingConstants {
    public static final String RASCUNHO = 'Rascunho';
    public static final String PENDENTE = 'Pendente';
    public static final String APROVADA = 'Aprovada';
    public static final String REJEITADA = 'Rejeitada';
    public static final String CANCELADA = 'Cancelada';

    public static final String NIVEL_AUTOMATICA = 'Automática';

    /** Limite maximo de desconto aceito pelo sistema (matriz: acima disso a submissao e bloqueada). */
    public static final Decimal DESCONTO_MAXIMO = 30;

    public static final String STATUS_ORDER_DRAFT = 'Draft';
}

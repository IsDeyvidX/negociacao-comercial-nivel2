/**
 * Acesso a matriz de aprovacao, que vive em Custom Metadata (Aprovacao_Nivel__mdt)
 * para ser portavel entre ambientes e sem nenhum Id hardcoded.
 * Regra de faixa: Percentual_Minimo < desconto <= Percentual_Maximo (minimo EXCLUSIVO).
 */
public with sharing class TrainingApprovalMatrix {

    public static List<Aprovacao_Nivel__mdt> allLevels() {
        return Aprovacao_Nivel__mdt.getAll().values();
    }

    public static Aprovacao_Nivel__mdt forPercent(Decimal percent) {
        Decimal pct = percent == null ? 0 : percent;
        for (Aprovacao_Nivel__mdt level : allLevels()) {
            if (level.Percentual_Minimo__c < pct && pct <= level.Percentual_Maximo__c) {
                return level;
            }
        }
        return null;
    }

    public static String nivelParaPercentual(Decimal percent) {
        Aprovacao_Nivel__mdt level = forPercent(percent);
        return level == null ? null : level.Nivel__c;
    }

    public static Aprovacao_Nivel__mdt byNivel(String nivel) {
        if (String.isBlank(nivel)) {
            return null;
        }
        for (Aprovacao_Nivel__mdt level : allLevels()) {
            if (level.Nivel__c == nivel) {
                return level;
            }
        }
        return null;
    }
}

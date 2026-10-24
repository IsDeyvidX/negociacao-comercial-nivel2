import os
BASE = 'force-app/main/default/flexipages'
NS = 'xmlns="http://soap.sforce.com/2006/04/metadata"'
HDR = '<?xml version="1.0" encoding="UTF-8"?>\n'
os.makedirs(BASE, exist_ok=True)

def visibility(status):
    if not status:
        return ''
    return (f'            <visibilityRule>\n                <criteria>\n                    <leftValue>{{!Record.Status__c}}</leftValue>\n'
            f'                    <operator>EQUAL</operator>\n                    <rightValue>{status}</rightValue>\n                </criteria>\n            </visibilityRule>\n')

def section(idx, label, fields, status=None):
    facet = f'Facet-0000000{idx}-aaaa-4bbb-8ccc-00000000000{idx}'
    comp = (f'        <itemInstances>\n            <componentInstance>\n'
            f'                <componentInstanceProperties>\n                    <name>columns</name>\n                    <value>{facet}</value>\n                </componentInstanceProperties>\n'
            f'                <componentInstanceProperties>\n                    <name>label</name>\n                    <value>{label}</value>\n                </componentInstanceProperties>\n'
            f'                <componentName>flexipage:fieldSection</componentName>\n                <identifier>flexipage_fieldSection{idx}</identifier>\n'
            + visibility(status).replace('            <visibilityRule>', '                <visibilityRule>').replace('\n                <criteria>', '\n                    <criteria>')
            + '            </componentInstance>\n        </itemInstances>\n')
    items = ''
    for f in fields:
        ident = 'Record' + f.replace('__c', '_c') + 'Field' + str(idx)
        items += (f'        <itemInstances>\n            <fieldInstance>\n                <fieldInstanceProperties>\n                    <name>uiBehavior</name>\n'
                  f'                    <value>readonly</value>\n                </fieldInstanceProperties>\n                <fieldItem>Record.{f}</fieldItem>\n'
                  f'                <identifier>{ident}</identifier>\n            </fieldInstance>\n        </itemInstances>\n')
    facet_xml = (f'    <flexiPageRegions>\n{items}        <mode>Replace</mode>\n        <name>{facet}</name>\n        <type>Facet</type>\n    </flexiPageRegions>\n')
    return comp, facet_xml

def comp(name, ident, status=None, props=''):
    return (f'        <itemInstances>\n            <componentInstance>\n{props}                <componentName>{name}</componentName>\n'
            f'                <identifier>{ident}</identifier>\n' + visibility(status).replace('            <visibilityRule>', '                <visibilityRule>') + '            </componentInstance>\n        </itemInstances>\n')

# ---------------------------------------------------------------- Pagina da Negociacao (US-05)
sections = [
    section(1, 'Valores e desconto', ['Opportunity__c', 'Status__c', 'Percentual_Desconto__c', 'Valor_Bruto__c', 'Valor_Desconto__c', 'Valor_Final__c']),
    section(2, 'Justificativa (rascunho)', ['Justificativa__c'], 'Rascunho'),
    section(3, 'Aguardando aprovacao', ['Nivel_Aprovacao__c', 'Aprovador__c', 'Ciclo_Aprovacao__c', 'Justificativa__c'], 'Pendente'),
    section(4, 'Resultado da aprovacao', ['Nivel_Aprovacao__c', 'Aprovador__c', 'Data_Aprovacao__c'], 'Aprovada'),
    section(5, 'Rejeicao', ['Motivo_Rejeicao__c', 'Aprovador__c', 'Data_Aprovacao__c', 'Justificativa__c'], 'Rejeitada'),
]
main = comp('c:trainingNegotiationActions', 'c_trainingNegotiationActions')
main += comp('c:trainingNegotiationSummary', 'c_trainingNegotiationSummary')
main += ''.join(s[0] for s in sections)
main += comp('force:relatedListContainer', 'force_relatedListContainer')
header = comp('force:highlightsPanel', 'force_highlightsPanel')
neg = (HDR + f'<FlexiPage {NS}>\n'
       f'    <flexiPageRegions>\n{header}        <mode>Replace</mode>\n        <name>header</name>\n        <type>Region</type>\n    </flexiPageRegions>\n'
       f'    <flexiPageRegions>\n{main}        <mode>Replace</mode>\n        <name>main</name>\n        <type>Region</type>\n    </flexiPageRegions>\n'
       + ''.join(s[1] for s in sections) +
       '    <masterLabel>Negociacao Comercial - Pagina Dinamica</masterLabel>\n'
       '    <parentFlexiPage>flexipage__default_rec_L</parentFlexiPage>\n'
       '    <sobjectType>Negociacao_Comercial__c</sobjectType>\n'
       '    <template>\n        <name>flexipage:recordHomeTemplateDesktop</name>\n    </template>\n'
       '    <type>RecordPage</type>\n</FlexiPage>\n')
# parentFlexiPage nao e necessario (e arriscado); remove
neg = neg.replace('    <parentFlexiPage>flexipage__default_rec_L</parentFlexiPage>\n', '')
open(os.path.join(BASE, 'Negociacao_Comercial_Record_Page.flexipage-meta.xml'), 'w', encoding='utf-8').write(neg)

# ---------------------------------------------------------------- Pagina da Opportunity com o simulador (nao ativada)
opp_main = comp('c:trainingNegotiationSimulator', 'c_trainingNegotiationSimulator') + comp('force:detailPanel', 'force_detailPanel')
opp = (HDR + f'<FlexiPage {NS}>\n'
       f'    <flexiPageRegions>\n{comp("force:highlightsPanel", "force_highlightsPanel")}        <mode>Replace</mode>\n        <name>header</name>\n        <type>Region</type>\n    </flexiPageRegions>\n'
       f'    <flexiPageRegions>\n{opp_main}        <mode>Replace</mode>\n        <name>main</name>\n        <type>Region</type>\n    </flexiPageRegions>\n'
       '    <masterLabel>Opportunity - Simulador de Negociacao</masterLabel>\n'
       '    <sobjectType>Opportunity</sobjectType>\n'
       '    <template>\n        <name>flexipage:recordHomeTemplateDesktop</name>\n    </template>\n'
       '    <type>RecordPage</type>\n</FlexiPage>\n')
open(os.path.join(BASE, 'Opportunity_Simulador_Record_Page.flexipage-meta.xml'), 'w', encoding='utf-8').write(opp)
print('flexipages ok')

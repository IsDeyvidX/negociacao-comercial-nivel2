import os
BASE = 'force-app/main/default'
NS = 'xmlns="http://soap.sforce.com/2006/04/metadata"'
HDR = '<?xml version="1.0" encoding="UTF-8"?>\n'

def w(path, content):
    full = os.path.join(BASE, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, 'w', encoding='utf-8') as f:
        f.write(content)

def esc(s):
    return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')

def field(obj, api, label, ftype, extra='', desc=None):
    d = f'    <description>{esc(desc)}</description>\n' if desc else ''
    xml = (HDR + f'<CustomField {NS}>\n    <fullName>{api}</fullName>\n{d}'
           f'    <label>{esc(label)}</label>\n    <type>{ftype}</type>\n{extra}</CustomField>\n')
    w(f'objects/{obj}/fields/{api}.field-meta.xml', xml)

def currency(obj, api, label, desc=None, default=None):
    dv = f'    <defaultValue>{default}</defaultValue>\n' if default is not None else ''
    field(obj, api, label, 'Currency', f'    <precision>16</precision>\n    <scale>2</scale>\n    <required>false</required>\n{dv}    <externalId>false</externalId>\n', desc)

def text(obj, api, label, length, unique=False, desc=None):
    u = '    <unique>true</unique>\n    <caseSensitive>true</caseSensitive>\n' if unique else ''
    field(obj, api, label, 'Text', f'    <length>{length}</length>\n    <required>false</required>\n{u}    <externalId>false</externalId>\n', desc)

def longtext(obj, api, label, desc=None):
    field(obj, api, label, 'LongTextArea', '    <length>32768</length>\n    <visibleLines>5</visibleLines>\n', desc)

def lookup(obj, api, label, ref, relname, rellabel, delete='SetNull', required=False, desc=None):
    req = '    <required>true</required>\n' if required else '    <required>false</required>\n'
    field(obj, api, label, 'Lookup',
          f'    <referenceTo>{ref}</referenceTo>\n    <relationshipLabel>{esc(rellabel)}</relationshipLabel>\n'
          f'    <relationshipName>{relname}</relationshipName>\n    <deleteConstraint>{delete}</deleteConstraint>\n{req}', desc)

def picklist(obj, api, label, values, default=None, desc=None):
    vals = ''
    for v in values:
        d = '            <default>true</default>\n' if v == default else '            <default>false</default>\n'
        vals += f'                <value>\n                    <fullName>{v}</fullName>\n{d.replace("            ", "                    ")}                    <label>{v}</label>\n                </value>\n'
    extra = ('    <required>false</required>\n    <valueSet>\n        <restricted>true</restricted>\n'
             '        <valueSetDefinition>\n            <sorted>false</sorted>\n' + vals +
             '        </valueSetDefinition>\n    </valueSet>\n')
    field(obj, api, label, 'Picklist', extra, desc)

# ---------------------------------------------------------------- Negociacao_Comercial__c
O = 'Negociacao_Comercial__c'
w(f'objects/{O}/{O}.object-meta.xml', HDR + f'''<CustomObject {NS}>
    <actionOverrides>
        <actionName>View</actionName>
        <comment>Pagina dinamica da negociacao (US-05)</comment>
        <content>Negociacao_Comercial_Record_Page</content>
        <formFactor>Large</formFactor>
        <skipRecordTypeSelect>false</skipRecordTypeSelect>
        <type>Flexipage</type>
    </actionOverrides>
    <allowInChatterGroups>false</allowInChatterGroups>
    <compactLayoutAssignment>SYSTEM</compactLayoutAssignment>
    <deploymentStatus>Deployed</deploymentStatus>
    <description>Negociacao de desconto vinculada a uma Opportunity (Treinamento Salesforce - Nivel 2)</description>
    <enableActivities>true</enableActivities>
    <enableBulkApi>true</enableBulkApi>
    <enableFeeds>false</enableFeeds>
    <enableHistory>true</enableHistory>
    <enableReports>true</enableReports>
    <enableSearch>true</enableSearch>
    <enableSharing>true</enableSharing>
    <enableStreamingApi>true</enableStreamingApi>
    <externalSharingModel>ReadWrite</externalSharingModel>
    <label>Negociação Comercial</label>
    <nameField>
        <displayFormat>NEG-{{0000}}</displayFormat>
        <label>Número da Negociação</label>
        <trackHistory>false</trackHistory>
        <type>AutoNumber</type>
    </nameField>
    <pluralLabel>Negociações Comerciais</pluralLabel>
    <searchLayouts></searchLayouts>
    <sharingModel>ReadWrite</sharingModel>
    <visibility>Public</visibility>
</CustomObject>
''')
lookup(O, 'Opportunity__c', 'Oportunidade', 'Opportunity', 'Negociacoes_Comerciais', 'Negociações Comerciais', 'Restrict', True)
currency(O, 'Valor_Bruto__c', 'Valor Bruto', 'Soma dos subtotais dos itens. Mantido exclusivamente pela Trigger de itens.', 0)
field(O, 'Percentual_Desconto__c', 'Percentual de Desconto', 'Percent', '    <precision>5</precision>\n    <scale>2</scale>\n    <required>false</required>\n    <defaultValue>0</defaultValue>\n', 'Entre 0 e 30. Valor 12 significa 12%.')
currency(O, 'Valor_Desconto__c', 'Valor do Desconto', 'Calculado pela Trigger: Valor Bruto x Percentual (HALF_UP, 2 casas).', 0)
currency(O, 'Valor_Final__c', 'Valor Final', 'Valor Bruto - Valor do Desconto.', 0)
picklist(O, 'Status__c', 'Status', ['Rascunho', 'Pendente', 'Aprovada', 'Rejeitada', 'Cancelada'], 'Rascunho')
picklist(O, 'Nivel_Aprovacao__c', 'Nível de Aprovação', ['Automática', 'Gerente', 'Diretor', 'Financeiro'], None, 'Calculado pela Trigger a partir da matriz (Custom Metadata Aprovacao_Nivel__mdt).')
longtext(O, 'Justificativa__c', 'Justificativa')
lookup(O, 'Aprovador__c', 'Aprovador', 'User', 'Negociacoes_Aprovador', 'Negociações (Aprovador)', 'SetNull', False, 'Aprovador esperado enquanto Pendente; usuário que decidiu após a decisão.')
field(O, 'Data_Aprovacao__c', 'Data/Hora da Decisão', 'DateTime', '    <required>false</required>\n')
longtext(O, 'Motivo_Rejeicao__c', 'Motivo da Rejeição')
field(O, 'Ciclo_Aprovacao__c', 'Ciclo de Aprovação', 'Number', '    <precision>3</precision>\n    <scale>0</scale>\n    <required>false</required>\n    <defaultValue>0</defaultValue>\n', 'Incrementado a cada submissão (Rascunho -> Pendente).')
text(O, 'Chave_Pendente__c', 'Chave de Pendência', 18, True, 'Preenchida com o Id da Opportunity enquanto Pendente. A constraint de unicidade garante no banco no máximo uma Pendente por Opportunity, mesmo em concorrência.')

# ---------------------------------------------------------------- Item_Negociacao__c
I = 'Item_Negociacao__c'
w(f'objects/{I}/{I}.object-meta.xml', HDR + f'''<CustomObject {NS}>
    <allowInChatterGroups>false</allowInChatterGroups>
    <compactLayoutAssignment>SYSTEM</compactLayoutAssignment>
    <deploymentStatus>Deployed</deploymentStatus>
    <description>Item (produto, quantidade, preco) de uma Negociacao Comercial</description>
    <enableActivities>false</enableActivities>
    <enableBulkApi>true</enableBulkApi>
    <enableFeeds>false</enableFeeds>
    <enableHistory>false</enableHistory>
    <enableReports>true</enableReports>
    <enableSearch>false</enableSearch>
    <enableSharing>true</enableSharing>
    <enableStreamingApi>true</enableStreamingApi>
    <externalSharingModel>ControlledByParent</externalSharingModel>
    <label>Item de Negociação</label>
    <nameField>
        <displayFormat>ITEM-{{00000}}</displayFormat>
        <label>Número do Item</label>
        <trackHistory>false</trackHistory>
        <type>AutoNumber</type>
    </nameField>
    <pluralLabel>Itens de Negociação</pluralLabel>
    <searchLayouts></searchLayouts>
    <sharingModel>ControlledByParent</sharingModel>
    <visibility>Public</visibility>
</CustomObject>
''')
field(I, 'Negociacao__c', 'Negociação', 'MasterDetail', f'    <referenceTo>{O}</referenceTo>\n    <relationshipLabel>Itens</relationshipLabel>\n    <relationshipName>Itens</relationshipName>\n    <relationshipOrder>0</relationshipOrder>\n    <reparentableMasterDetail>true</reparentableMasterDetail>\n    <writeRequiresMasterRead>false</writeRequiresMasterRead>\n')
lookup(I, 'Produto__c', 'Produto', 'Product2', 'Itens_Negociacao', 'Itens de Negociação', 'Restrict')
field(I, 'Quantidade__c', 'Quantidade', 'Number', '    <precision>8</precision>\n    <scale>0</scale>\n    <required>false</required>\n', 'Inteiro >= 1 (validado na Trigger).')
currency(I, 'Preco_Unitario__c', 'Preço Unitário', 'Maior que zero (validado na Trigger). Preenchido pelo servidor a partir do PricebookEntry.')
currency(I, 'Subtotal__c', 'Subtotal', 'Quantidade x Preço Unitário, arredondado HALF_UP em 2 casas. Calculado pela Trigger (campo físico para permitir SUM em SOQL).')

# ---------------------------------------------------------------- Historico_Decisao__c
H = 'Historico_Decisao__c'
w(f'objects/{H}/{H}.object-meta.xml', HDR + f'''<CustomObject {NS}>
    <allowInChatterGroups>false</allowInChatterGroups>
    <compactLayoutAssignment>SYSTEM</compactLayoutAssignment>
    <deploymentStatus>Deployed</deploymentStatus>
    <description>Trilha de auditoria das decisoes e transicoes de uma Negociacao Comercial</description>
    <enableActivities>false</enableActivities>
    <enableBulkApi>true</enableBulkApi>
    <enableFeeds>false</enableFeeds>
    <enableHistory>false</enableHistory>
    <enableReports>true</enableReports>
    <enableSearch>false</enableSearch>
    <enableSharing>true</enableSharing>
    <enableStreamingApi>true</enableStreamingApi>
    <externalSharingModel>ControlledByParent</externalSharingModel>
    <label>Histórico de Decisão</label>
    <nameField>
        <displayFormat>HIST-{{000000}}</displayFormat>
        <label>Número do Histórico</label>
        <trackHistory>false</trackHistory>
        <type>AutoNumber</type>
    </nameField>
    <pluralLabel>Históricos de Decisão</pluralLabel>
    <searchLayouts></searchLayouts>
    <sharingModel>ControlledByParent</sharingModel>
    <visibility>Public</visibility>
</CustomObject>
''')
field(H, 'Negociacao__c', 'Negociação', 'MasterDetail', f'    <referenceTo>{O}</referenceTo>\n    <relationshipLabel>Histórico de Decisões</relationshipLabel>\n    <relationshipName>Historico_Decisoes</relationshipName>\n    <relationshipOrder>0</relationshipOrder>\n    <reparentableMasterDetail>false</reparentableMasterDetail>\n    <writeRequiresMasterRead>false</writeRequiresMasterRead>\n')
field(H, 'Ciclo__c', 'Ciclo', 'Number', '    <precision>3</precision>\n    <scale>0</scale>\n    <required>false</required>\n')
text(H, 'Decisao__c', 'Evento / Decisão', 60)
text(H, 'Status_Anterior__c', 'Status Anterior', 20)
text(H, 'Status_Novo__c', 'Status Novo', 20)
text(H, 'Nivel_Aprovacao__c', 'Nível de Aprovação', 20)
longtext(H, 'Motivo__c', 'Motivo')
lookup(H, 'Usuario__c', 'Usuário', 'User', 'Historicos_Usuario', 'Históricos (Usuário)')
lookup(H, 'Aprovador_Esperado__c', 'Aprovador Esperado', 'User', 'Historicos_Aprovador_Esperado', 'Históricos (Aprovador Esperado)')
field(H, 'Data_Hora__c', 'Data/Hora', 'DateTime', '    <required>false</required>\n')
text(H, 'Origem__c', 'Origem', 80)

# ---------------------------------------------------------------- campos em objetos standard
lookup('Order', 'Negociacao_Comercial__c', 'Negociação Comercial', O, 'Pedidos', 'Pedidos', 'Restrict')
text('Order', 'Negociacao_Origem_Id__c', 'Id da Negociação de Origem', 18, True, 'Chave única: impede mais de um Order por negociação, inclusive sob concorrência.')
lookup('Order', 'Oportunidade_Origem__c', 'Oportunidade de Origem', 'Opportunity', 'Pedidos_Origem', 'Pedidos de Origem', 'Restrict')
text('Activity', 'Chave_Idempotencia__c', 'Chave de Idempotência', 80, False, 'Id da negociação + ciclo. Evita tarefa de aprovação duplicada em reprocessamentos do Flow.')

# ---------------------------------------------------------------- Custom Metadata Type
M = 'Aprovacao_Nivel__mdt'
w(f'objects/{M}/{M}.object-meta.xml', HDR + f'''<CustomObject {NS}>
    <description>Matriz de aprovação (faixas de desconto, permissão e aprovador) - portável entre ambientes</description>
    <label>Aprovação Nível</label>
    <pluralLabel>Aprovação Níveis</pluralLabel>
    <visibility>Public</visibility>
</CustomObject>
''')
def mdtfield(api, label, ftype, extra, desc):
    field(M, api, label, ftype, extra + '    <fieldManageability>DeveloperControlled</fieldManageability>\n', desc)
mdtfield('Nivel__c', 'Nível', 'Text', '    <length>40</length>\n    <required>true</required>\n    <externalId>false</externalId>\n    <unique>false</unique>\n', 'Deve ser idêntico ao valor da picklist Negociacao_Comercial__c.Nivel_Aprovacao__c.')
mdtfield('Percentual_Minimo__c', 'Percentual Mínimo (exclusivo)', 'Number', '    <precision>5</precision>\n    <scale>2</scale>\n    <required>true</required>\n    <externalId>false</externalId>\n', 'Limite inferior EXCLUSIVO (use -1 para incluir 0%).')
mdtfield('Percentual_Maximo__c', 'Percentual Máximo (inclusivo)', 'Number', '    <precision>5</precision>\n    <scale>2</scale>\n    <required>true</required>\n    <externalId>false</externalId>\n', 'Limite superior INCLUSIVO.')
mdtfield('Aprovacao_Automatica__c', 'Aprovação Automática', 'Checkbox', '    <defaultValue>false</defaultValue>\n', None)
mdtfield('Custom_Permission__c', 'Custom Permission', 'Text', '    <length>80</length>\n    <required>false</required>\n    <externalId>false</externalId>\n    <unique>false</unique>\n', 'DeveloperName da Custom Permission que autoriza decidir neste nível.')
mdtfield('Aprovador_Username__c', 'Aprovador (Username opcional)', 'Text', '    <length>80</length>\n    <required>false</required>\n    <externalId>false</externalId>\n    <unique>false</unique>\n', 'Opcional: username do aprovador padrão do ambiente. Se vazio, usa o primeiro usuário ativo com o Permission Set do nível.')

def mdt(dev, label, nivel, mn, mx, auto, perm):
    vals = [('Nivel__c', 'string', nivel), ('Percentual_Minimo__c', 'double', mn), ('Percentual_Maximo__c', 'double', mx),
            ('Aprovacao_Automatica__c', 'boolean', 'true' if auto else 'false'), ('Custom_Permission__c', 'string', perm)]
    body = ''
    for f, t, v in vals:
        if v is None:
            continue
        body += f'    <values>\n        <field>{f}</field>\n        <value xsi:type="xsd:{t}">{v}</value>\n    </values>\n'
    w(f'customMetadata/Aprovacao_Nivel.{dev}.md-meta.xml', HDR + f'''<CustomMetadata {NS} xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <label>{label}</label>
    <protected>false</protected>
{body}</CustomMetadata>
''')
mdt('Automatica', 'Automática', 'Automática', '-1.0', '5.0', True, None)
mdt('Gerente', 'Gerente', 'Gerente', '5.0', '10.0', False, 'Aprovar_Negociacao_Gerente')
mdt('Diretor', 'Diretor', 'Diretor', '10.0', '20.0', False, 'Aprovar_Negociacao_Diretor')
mdt('Financeiro', 'Financeiro', 'Financeiro', '20.0', '30.0', False, 'Aprovar_Negociacao_Financeiro')

# ---------------------------------------------------------------- Custom Permissions
for lvl in ['Gerente', 'Diretor', 'Financeiro']:
    w(f'customPermissions/Aprovar_Negociacao_{lvl}.customPermission-meta.xml', HDR + f'''<CustomPermission {NS}>
    <isLicensed>false</isLicensed>
    <label>Aprovar Negociação ({lvl})</label>
</CustomPermission>
''')

# ---------------------------------------------------------------- Tab + App
w(f'tabs/{O}.tab-meta.xml', HDR + f'''<CustomTab {NS}>
    <customObject>true</customObject>
    <motif>Custom57: Grid</motif>
</CustomTab>
''')
w('applications/Training_Negociacao.app-meta.xml', HDR + f'''<CustomApplication {NS}>
    <brand>
        <headerColor>#0176D3</headerColor>
        <shadeHeader>false</shadeHeader>
    </brand>
    <formFactors>Large</formFactors>
    <isNavAutoTempTabsDisabled>false</isNavAutoTempTabsDisabled>
    <isNavPersonalizationDisabled>false</isNavPersonalizationDisabled>
    <label>Training Negociações</label>
    <navType>Standard</navType>
    <tabs>standard-Opportunity</tabs>
    <tabs>{O}</tabs>
    <uiType>Lightning</uiType>
</CustomApplication>
''')

# ---------------------------------------------------------------- Permission Sets
CLASSES = ['TrainingNegotiationController', 'TrainingOrderController', 'TrainingApprovalDecisionAction']
def permset(name, label, desc, custom_perm=None, approver=False):
    objs = ''
    def obj(o, c, r, e, d):
        return (f'    <objectPermissions>\n        <allowCreate>{c}</allowCreate>\n        <allowDelete>{d}</allowDelete>\n'
                f'        <allowEdit>{e}</allowEdit>\n        <allowRead>{r}</allowRead>\n        <modifyAllRecords>false</modifyAllRecords>\n'
                f'        <object>{o}</object>\n        <viewAllRecords>false</viewAllRecords>\n    </objectPermissions>\n')
    objs += obj(O, 'true', 'true', 'true', 'true')
    objs += obj(I, 'true', 'true', 'true', 'true')
    objs += obj(H, 'false', 'true', 'false', 'false')   # historico: somente leitura (gravado em modo sistema)
    objs += obj('Opportunity', 'false', 'true', 'false', 'false')
    objs += obj('Account', 'false', 'true', 'false', 'false')
    objs += obj('Product2', 'false', 'true', 'false', 'false')
    objs += obj('Order', 'true', 'true', 'false', 'false')
    objs += obj('OrderItem', 'true', 'true', 'false', 'false')
    def fp(f, rw):
        return f'    <fieldPermissions>\n        <editable>{"true" if rw else "false"}</editable>\n        <field>{f}</field>\n        <readable>true</readable>\n    </fieldPermissions>\n'
    fps = ''
    seller_rw = ['Percentual_Desconto__c', 'Justificativa__c', 'Status__c']
    approver_rw = seller_rw + (['Aprovador__c', 'Data_Aprovacao__c', 'Motivo_Rejeicao__c'] if approver else [])
    for f in ['Valor_Bruto__c', 'Percentual_Desconto__c', 'Valor_Desconto__c', 'Valor_Final__c', 'Status__c', 'Nivel_Aprovacao__c',
              'Justificativa__c', 'Aprovador__c', 'Data_Aprovacao__c', 'Motivo_Rejeicao__c', 'Ciclo_Aprovacao__c', 'Chave_Pendente__c']:
        fps += fp(f'{O}.{f}', f in approver_rw)
    for f in ['Produto__c', 'Quantidade__c', 'Preco_Unitario__c']:
        fps += fp(f'{I}.{f}', True)
    fps += fp(f'{I}.Subtotal__c', False)
    for f in ['Ciclo__c', 'Decisao__c', 'Status_Anterior__c', 'Status_Novo__c', 'Nivel_Aprovacao__c', 'Motivo__c', 'Usuario__c',
              'Aprovador_Esperado__c', 'Data_Hora__c', 'Origem__c']:
        fps += fp(f'{H}.{f}', False)
    for f in ['Negociacao_Comercial__c', 'Negociacao_Origem_Id__c', 'Oportunidade_Origem__c']:
        fps += fp(f'Order.{f}', True)
    cls = ''.join(f'    <classAccesses>\n        <apexClass>{c}</apexClass>\n        <enabled>true</enabled>\n    </classAccesses>\n' for c in CLASSES)
    cp = f'    <customPermissions>\n        <enabled>true</enabled>\n        <name>{custom_perm}</name>\n    </customPermissions>\n' if custom_perm else ''
    w(f'permissionsets/{name}.permissionset-meta.xml', HDR + f'''<PermissionSet {NS}>
    <applicationVisibilities>
        <application>Training_Negociacao</application>
        <visible>true</visible>
    </applicationVisibilities>
{cls}{cp}    <description>{esc(desc)}</description>
{fps}    <hasActivationRequired>false</hasActivationRequired>
    <label>{esc(label)}</label>
{objs}    <tabSettings>
        <tab>{O}</tab>
        <visibility>Visible</visibility>
    </tabSettings>
</PermissionSet>
''')
permset('Training_Vendedor', 'Training - Vendedor', 'Monta negociações, envia para aprovação e gera pedidos. NÃO decide aprovações.')
permset('Training_Aprovador_Gerente', 'Training - Aprovador Gerente', 'Decide negociações do nível Gerente (>5% até 10%).', 'Aprovar_Negociacao_Gerente', True)
permset('Training_Aprovador_Diretor', 'Training - Aprovador Diretor', 'Decide negociações do nível Diretor (>10% até 20%).', 'Aprovar_Negociacao_Diretor', True)
permset('Training_Aprovador_Financeiro', 'Training - Aprovador Financeiro', 'Decide negociações do nível Financeiro (>20% até 30%).', 'Aprovar_Negociacao_Financeiro', True)
print('metadata ok')

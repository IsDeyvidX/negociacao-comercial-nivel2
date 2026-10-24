// Dados de demonstracao (Execute Anonymous). Executa como o usuario logado no VS Code / Developer Console.
// sf apex run --file scripts/apex/seed-demo.apex --target-org minha_nova_org
Pricebook2 std = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
Account acc = new Account(Name = 'Concessionária Demo Nível 2');
insert acc;

List<Product2> products = new List<Product2>();
for (Integer i = 1; i <= 5; i++) {
    products.add(new Product2(Name = 'Veículo Demo ' + i, ProductCode = 'DEMO-' + i, IsActive = true));
}
insert products;

List<PricebookEntry> entries = new List<PricebookEntry>();
for (Integer i = 0; i < products.size(); i++) {
    entries.add(new PricebookEntry(Pricebook2Id = std.Id, Product2Id = products[i].Id, UnitPrice = 50000 + (i * 7500), IsActive = true));
}
insert entries;

Opportunity opp = new Opportunity(Name = 'Oportunidade Demo Nível 2', AccountId = acc.Id, StageName = 'Prospecting',
    CloseDate = Date.today().addDays(30), Pricebook2Id = std.Id);
insert opp;

System.debug('Oportunidade criada: ' + opp.Id + ' -> abra o registro e use o Simulador de Negociação.');

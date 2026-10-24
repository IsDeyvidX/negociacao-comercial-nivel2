import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import CURRENCY from '@salesforce/i18n/currency';
import getView from '@salesforce/apex/TrainingNegotiationController.getView';
import STATUS from '@salesforce/schema/Negociacao_Comercial__c.Status__c';
import MODIFIED from '@salesforce/schema/Negociacao_Comercial__c.LastModifiedDate';

const COLUMNS = [
    { label: 'Produto', fieldName: 'productName' },
    { label: 'Código', fieldName: 'productCode' },
    { label: 'Qtd.', fieldName: 'quantity', type: 'number', cellAttributes: { alignment: 'right' } },
    { label: 'Preço unitário', fieldName: 'unitPrice', type: 'currency', typeAttributes: { currencyCode: CURRENCY } },
    { label: 'Subtotal', fieldName: 'subtotal', type: 'currency', typeAttributes: { currencyCode: CURRENCY } }
];

const BADGE_BY_STATUS = {
    Rascunho: 'slds-badge',
    Pendente: 'slds-badge slds-theme_warning',
    Aprovada: 'slds-badge slds-theme_success',
    Rejeitada: 'slds-badge slds-theme_error',
    Cancelada: 'slds-badge slds-theme_offline'
};

export default class TrainingNegotiationSummary extends LightningElement {
    @api recordId;

    columns = COLUMNS;
    currencyCode = CURRENCY;
    view;
    error;

    // O wire do LDS dispara de novo sempre que o registro muda (status, aprovação etc.).
    @wire(getRecord, { recordId: '$recordId', fields: [STATUS, MODIFIED] })
    wiredRecord({ data, error }) {
        if (data) {
            this.load();
        } else if (error) {
            this.error = 'Não foi possível carregar a negociação.';
        }
    }

    @api
    refresh() {
        return this.load();
    }

    async load() {
        if (!this.recordId) {
            return;
        }
        try {
            this.view = await getView({ negotiationId: this.recordId });
            this.error = undefined;
        } catch (e) {
            this.error = (e && e.body && e.body.message) || 'Não foi possível carregar a negociação.';
        }
    }

    get badgeClass() {
        return BADGE_BY_STATUS[this.view.status] || 'slds-badge';
    }

    get hasItems() {
        return this.view && this.view.items && this.view.items.length > 0;
    }

    get isRejected() {
        return this.view && this.view.status === 'Rejeitada';
    }

    get isPending() {
        return this.view && this.view.status === 'Pendente';
    }

    get isApproved() {
        return this.view && this.view.status === 'Aprovada';
    }

    get hasOrder() {
        return this.view && !!this.view.orderId;
    }

    get approverLabel() {
        if (!this.view || !this.view.approverName) {
            return 'Ainda não definido';
        }
        return this.view.approverName;
    }
}

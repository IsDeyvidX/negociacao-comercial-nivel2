import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord, notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getView from '@salesforce/apex/TrainingNegotiationController.getView';
import submitNegotiation from '@salesforce/apex/TrainingNegotiationController.submitNegotiation';
import reopenNegotiation from '@salesforce/apex/TrainingNegotiationController.reopenNegotiation';
import cancelNegotiation from '@salesforce/apex/TrainingNegotiationController.cancelNegotiation';
import generateOrder from '@salesforce/apex/TrainingOrderController.generateOrder';
import STATUS from '@salesforce/schema/Negociacao_Comercial__c.Status__c';
import MODIFIED from '@salesforce/schema/Negociacao_Comercial__c.LastModifiedDate';

export default class TrainingNegotiationActions extends NavigationMixin(LightningElement) {
    @api recordId;

    view;
    busy = false;
    showSimulator = false;
    showDecision = false;

    @wire(getRecord, { recordId: '$recordId', fields: [STATUS, MODIFIED] })
    wiredRecord({ data }) {
        if (data) {
            this.load();
        }
    }

    async load() {
        try {
            this.view = await getView({ negotiationId: this.recordId });
        } catch (e) {
            this.view = undefined;
        }
    }

    // A visibilidade abaixo é só conveniência de UX: toda ação é revalidada no servidor.
    get isDraft() { return this.view && this.view.status === 'Rascunho'; }
    get isPending() { return this.view && this.view.status === 'Pendente'; }
    get isApproved() { return this.view && this.view.status === 'Aprovada'; }
    get isRejected() { return this.view && this.view.status === 'Rejeitada'; }
    get canDecide() { return this.isPending && this.view.canDecide; }
    get canGenerate() { return this.isApproved && this.view.canGenerateOrder; }
    get hasOrder() { return this.isApproved && !!this.view.orderId; }
    get canCancel() { return this.isDraft || this.isPending || this.isRejected; }
    get flowInputs() { return [{ name: 'recordId', type: 'String', value: this.recordId }]; }

    // ---------------------------------------------------------------- ações
    async run(action, successFallback) {
        this.busy = true;
        try {
            const result = await action();
            this.toast('Sucesso', (result && result.message) || successFallback, 'success');
            await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            await this.load();
            return result;
        } catch (error) {
            this.toast('Não foi possível concluir', this.reduceError(error), 'error');
            return undefined;
        } finally {
            this.busy = false;
        }
    }

    handleSubmit() {
        return this.run(() => submitNegotiation({ negotiationId: this.recordId }), 'Negociação enviada.');
    }

    handleReopen() {
        return this.run(() => reopenNegotiation({ negotiationId: this.recordId }), 'Negociação reaberta para revisão.');
    }

    handleCancel() {
        return this.run(() => cancelNegotiation({ negotiationId: this.recordId }), 'Negociação cancelada.');
    }

    async handleGenerateOrder() {
        const result = await this.run(() => generateOrder({ negotiationId: this.recordId }), 'Pedido gerado.');
        if (result && result.orderId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId: result.orderId, objectApiName: 'Order', actionName: 'view' }
            });
        }
    }

    handleOpenOrder() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.view.orderId, objectApiName: 'Order', actionName: 'view' }
        });
    }

    // ---------------------------------------------------------------- modais
    handleOpenSimulator() { this.showSimulator = true; }
    handleCloseSimulator() { this.showSimulator = false; }
    async handleSimulatorSaved() {
        this.showSimulator = false;
        await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
        await this.load();
    }

    handleOpenDecision() { this.showDecision = true; }
    handleCloseDecision() { this.showDecision = false; }
    async handleFlowStatus(event) {
        const status = event.detail.status;
        if (status === 'FINISHED' || status === 'FINISHED_SCREEN') {
            this.showDecision = false;
            await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            await this.load();
        }
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    reduceError(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        return (error && error.message) || 'Erro inesperado.';
    }
}

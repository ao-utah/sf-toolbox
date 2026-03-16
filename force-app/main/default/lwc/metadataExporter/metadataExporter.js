import { LightningElement, track } from 'lwc';
import getObjectNames from '@salesforce/apex/MetadataExportController.getObjectNames';
import generateCsvForObjects from '@salesforce/apex/MetadataExportController.generateCsvForObjects';

export default class MetadataExporter extends LightningElement {
    @track _allObjects = [];
    @track searchKeyword = '';
    @track isLoadingObjects = true;
    @track isLoading = false;
    @track csvOutput = '';
    @track errorMessage = '';
    @track outputFormat = 'csv';
    connectedCallback() {
        this.loadObjects();
    }

    loadObjects() {
        this.isLoadingObjects = true;
        this._allObjects = [];
        getObjectNames({ includePackageObjects: false })
            .then((data) => {
                this._allObjects = data.map((obj) => ({
                    name: obj.name,
                    label: obj.label,
                    checked: false
                }));
                this.isLoadingObjects = false;
            })
            .catch((error) => {
                this.errorMessage = 'オブジェクト一覧の取得に失敗しました: ' + (error.body?.message ?? error.message ?? '不明なエラー');
                this.isLoadingObjects = false;
            });
    }

    // native textarea は template binding できないため renderedCallback で値をセット
    renderedCallback() {
        const ta = this.template.querySelector('.output-textarea');
        if (ta) {
            ta.value = this.csvOutput;
        }
    }

    get filteredObjects() {
        const keyword = this.searchKeyword.toLowerCase().trim();
        const source = keyword
            ? this._allObjects.filter(
                (obj) =>
                    obj.name.toLowerCase().includes(keyword) ||
                    obj.label.toLowerCase().includes(keyword)
            )
            : this._allObjects;
        return source.map((obj) => ({
            name: obj.name,
            label: obj.label,
            checked: obj.checked,
            checkboxLabel: `${obj.label} (${obj.name})`
        }));
    }

    get selectedCount() {
        return this._allObjects.filter((obj) => obj.checked).length;
    }

    get isOutputDisabled() {
        return this.selectedCount === 0 || this.isLoading;
    }

    get formatOptions() {
        return [
            { label: 'CSV', value: 'csv' },
            { label: 'TSV（表計算ソフト向け）', value: 'tsv' }
        ];
    }

    handleFormatChange(event) {
        this.outputFormat = event.detail.value;
        this.csvOutput = '';
    }

    handleSearch(event) {
        this.searchKeyword = event.target.value;
    }

    handleCheck(event) {
        const name = event.target.dataset.name;
        const checked = event.target.checked;
        const idx = this._allObjects.findIndex((obj) => obj.name === name);
        if (idx !== -1) {
            this._allObjects[idx] = { name: this._allObjects[idx].name, label: this._allObjects[idx].label, checked };
        }
    }

    handleSelectAll() {
        const visibleNames = new Set(this.filteredObjects.map((obj) => obj.name));
        this._allObjects = this._allObjects.map((obj) =>
            visibleNames.has(obj.name) ? { name: obj.name, label: obj.label, checked: true } : obj
        );
    }

    handleDeselectAll() {
        const visibleNames = new Set(this.filteredObjects.map((obj) => obj.name));
        this._allObjects = this._allObjects.map((obj) =>
            visibleNames.has(obj.name) ? { name: obj.name, label: obj.label, checked: false } : obj
        );
    }

    handleOutput() {
        const selectedObjects = this._allObjects
            .filter((obj) => obj.checked)
            .map((obj) => obj.name);

        this._allObjects = this._allObjects.map(obj => ({ ...obj }));
        this.isLoading = true;
        this.csvOutput = '';
        this.errorMessage = '';

        generateCsvForObjects({ selectedObjects, format: this.outputFormat })
            .then((result) => {
                this.csvOutput = result;
            })
            .catch((error) => {
                this.errorMessage = 'エラーが発生しました: ' + (error.body?.message ?? error.message ?? '不明なエラー');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleCopy() {
        navigator.clipboard.writeText(this.csvOutput).catch(() => {
            this.errorMessage = 'クリップボードへのコピーに失敗しました。';
        });
    }
}
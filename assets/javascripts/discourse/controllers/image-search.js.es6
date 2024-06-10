import Controller from '@ember/controller';

export default Controller.extend({
    searching: false,
    searchTerm: '',
    get searchTypes() {
        // TODO: i18n
        return [
            { name: 'OCR & Description', id: 'image_search_ocr_and_description' },
            { name: 'OCR', id: 'image_search_ocr' },
            { name: 'Description', id: 'image_search_description' }
        ];
    },
    get resultEntries() {
        return [
            { text: "123" },
            { text: "456" },
            { text: "789" }
        ];
    },

    init() {
        this._super(...arguments);
        this.set('search_type', this.searchTypes[0].id);
    },

    actions: {
        search(options = {}) {
            if (this.get('searchTerm').length < 3) {
                this.set('invalidSearch', true);
                return;
            }
            this.set('invalidSearch', false);
            this.set('searching', true);
            // this.transitionToRoute('image-search', query);
            console.log('searching for', this.get('search_type'), this.get('searchTerm'));
        }
    }
});
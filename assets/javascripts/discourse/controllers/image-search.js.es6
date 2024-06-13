import Controller from '@ember/controller';
import { action, computed } from '@ember/object';
import { ajax } from "discourse/lib/ajax";

export default class extends Controller {
    searching = false;
    searchTerm = '';
    repeat = 1;
    searchResults = {};

    // TODO: i18n
    searchTypes = [
        { name: 'OCR & Description', id: 'image_search_ocr_and_description' },
        { name: 'OCR', id: 'image_search_ocr' },
        { name: 'Description', id: 'image_search_description' }
    ];

    searchType = this.searchTypes[0].id;
    constructor() {
        super(...arguments);
    }

    _search() {
        const searchData = {};
        searchData.term = this.get('searchTerm');
        switch(this.get('searchType')){
            case 'image_search_ocr_and_description':
                searchData.ocr = true;
                searchData.description = true;
                break;
            case 'image_search_ocr':
                searchData.ocr = true;
                searchData.description = false;
                break;
            case 'image_search_description':
                searchData.ocr = false;
                searchData.description = true;
                break;
        }
        return ajax('/image-search/search.json', { data: searchData });
    }

    @computed('searching','searchResults')
    get resultEntries() {
        if (this.get('searching')) {return [];}
        return this.get('searchResults').image_search_result?.grouped_results ?? [];
    }

    @action
    search() {
        if (this.searchTerm.length < 2) {
            this.set('invalidSearch',true);
            return;
        }
        this.set('invalidSearch', false);
        this.set('searching', true);
        this._search().then((result) => {
            this.set('searchResults', result);
            this.set('searching', false);
        });
        // this.transitionToRoute('image-search', query);
        // this.set('repeat', this.get('repeat') + 1);
        console.log('searching for', this.searchType, this.searchTerm);
    }
}

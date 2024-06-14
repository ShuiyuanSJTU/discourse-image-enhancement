import Controller from '@ember/controller';
import { action, computed } from '@ember/object';
import { ajax } from "discourse/lib/ajax";

export default class extends Controller {
    searching = false;
    loadingMore = false;
    noMoreResults = false;
    searchActive = false;
    searchTerm = '';
    page = 0;
    searchResults = {};
    searchResultEntries = [];
    searchResultEntriesCount = 0;

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
        searchData.page = this.get('page');
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

    @computed('searching','searchResultEntries')
    get resultEntries() {
        if (this.get('searching')) {return [];}
        return this.get('searchResultEntries') ?? [];
    }

    @computed('searchResultEntries')
    get hasResults() {
        return this.get('searchResultEntries').length > 0;
    }

    resetSearch() {
        this.set('page', 0);
        this.set('searchResultEntries', []);
        this.set('searchResultEntriesCount', 0);
        this.set('loadingMore', false);
        this.set('noMoreResults', false);
    }

    @action
    search() {
        this.set('searchActive', true);
        if (this.searchTerm.length < 2) {
            this.set('invalidSearch',true);
            return;
        }
        this.set('invalidSearch', false);
        this.resetSearch();
        this.set('searching', true);
        this._search().then((result) => {
            this.set('searchResultEntries', result.image_search_result.grouped_results);
            this.set('noMoreResults', !result.image_search_result.has_more);
            this.set('searchResultEntriesCount', this.searchResultEntries.length);
            this.set('searching', false);
        });
    }

    @action
    loadMore() {
        if (this.get('searching') || this.get('loadingMore') || this.get('noMoreResults')) {return;}
        this.set('loadingMore', true);
        this.set('page', this.page + 1);
        this._search().then((result) => {
            this.set('noMoreResults', !result.image_search_result.has_more);
            if (result.image_search_result.grouped_results.length > 0) {
                this.set('searchResultEntries', this.searchResultEntries.concat(result.image_search_result.grouped_results));
                this.set('searchResultEntriesCount', this.searchResultEntries.length);
            }
            this.set('loadingMore', false);
        });
        let newResults = this.get('searchResultEntries');
        newResults = newResults.concat(newResults);
        this.set('searchResultEntries', newResults);
    }
}

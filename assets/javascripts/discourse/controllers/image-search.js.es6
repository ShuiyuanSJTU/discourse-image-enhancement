import Controller from '@ember/controller';
import { action, computed } from '@ember/object';
import { ajax } from "discourse/lib/ajax";
import I18n from "discourse-i18n";

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
        {
            name: I18n.t('image_search.search_type.ocr_and_desc'),
            id: 'image_search_ocr_and_description'
        },
        {
            name: I18n.t('image_search.search_type.ocr_only'),
            id: 'image_search_ocr'
        },
        {
            name: I18n.t('image_search.search_type.desc_only'),
            id: 'image_search_description'
        }
    ];

    searchType = this.searchTypes[0].id;
    _searchType = undefined;
    _searchTerm = undefined;
    constructor() {
        super(...arguments);
    }

    _search() {
        const searchData = {};
        searchData.term = this.get('_searchTerm');
        searchData.page = this.get('page');
        switch(this.get('_searchType')){
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
        this.set('_searchTerm', this.searchTerm);
        this.set('_searchType', this.searchType);
        this.set('searching', true);
        this._search().then((result) => {
            this.set('searchResultEntries', Array.from(result.image_search_result.grouped_results));
            this.set('noMoreResults', !result.image_search_result.has_more);
            this.set('searchResultEntriesCount', this.get('searchResultEntries').length);
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
                this.set('searchResultEntries', this.get('searchResultEntries').concat(result.image_search_result.grouped_results));
                this.set('searchResultEntriesCount', this.get('searchResultEntries').length);
            }
            this.set('loadingMore', false);
        });
    }
}

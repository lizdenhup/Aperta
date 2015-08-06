import Ember from 'ember';

export default Ember.Controller.extend({
  papers: [],
  unreadComments: [],
  pendingInvitations: Ember.computed('currentUser.invitedInvitations', function() {
    return this.get('currentUser.invitedInvitations');
  }),

  hasPapers: Ember.computed.notEmpty('papers'),
  pageNumber: 1,
  relatedAtSort: ['relatedAtDate:desc'],
  sortedPapers: Ember.computed.sort('papers', 'relatedAtSort'),

  totalPaperCount: Ember.computed('papers.length', function() {
    let numPapersFromServer       = this.store.metadataFor('paper').total_papers;
    let numDashboardPapersInStore = this.get('papers.length');

    return numDashboardPapersInStore > numPapersFromServer ? numDashboardPapersInStore : numPapersFromServer;
  }),

  canLoadMore: Ember.computed('pageNumber', function() {
    return this.get('pageNumber') !== this.store.metadataFor('paper').total_pages;
  }),

  actions: {
    loadMorePapers() {
      this.store.find('paper', { page_number: this.get('pageNumber') + 1 }).then(()=> {
        this.incrementProperty('pageNumber');
      });
    }
  }
});

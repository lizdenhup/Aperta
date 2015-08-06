import Ember from 'ember';

export default Ember.Controller.extend({
  sortProperties: ['createdAt'],
  sortAscending: false,
  placeholderText: 'Need to find a user? Search for them here.',
  searchQuery: '',

  resetSearch() {
    this.set('adminJournalUsers', null);
    this.set('placeholderText', null);
  },

  displayMatchNotFoundMessage() {
    this.set('placeholderText', 'No matching users found');
  },

  actions: {
    searchUsers() {
      this.resetSearch();
      this.store.find( 'admin-journal-user', {query: this.get('searchQuery')} ).then((users) => {
        this.set('adminJournalUsers', users);
        if(Ember.isEmpty(users)) { this.displayMatchNotFoundMessage(); }
      });
    }
  }
});

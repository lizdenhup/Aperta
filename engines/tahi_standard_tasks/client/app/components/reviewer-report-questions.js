import Ember from 'ember';

export default Ember.Component.extend({
  readOnly: false,

  reviewerStatus: Ember.computed('model.status', function() {
    const status = this.get('model.status');
    return status;
  }),

  competingInterestsLink: Ember.computed('model.task.paper.journal.name', function() {
    const name = this.get('model.task.paper.journal.name');
    if (name) {
      return `http://journals.plos.org/${name.toLowerCase().replace(' ', '')}/s/reviewer-guidelines#loc-competing-interests`;
    } else {
      return 'http://journals.plos.org/';
    }
  }),
});

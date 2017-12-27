import Ember from 'ember';
import moment from 'moment';

export default Ember.Component.extend({
  classNames: ['co-author-confirmation'],
  dateCreated: Ember.computed('author.createdAt', function() {
    return moment(this.get('author.createdAt')).format('ll');
  }),
  isConfirmed: Ember.computed.equal('author.confirmationState', 'confirmed'),
  isConfirmable: Ember.computed.equal('author.confirmationState', 'unconfirmed'),

  actions: {
    save() {
      this.set('author.confirmationState', 'confirmed');
      this.get('author').save();
    }
  }
});

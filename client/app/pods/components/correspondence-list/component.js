import Ember from 'ember';
import moment from 'moment';

export default Ember.Component.extend({
  isRecordLost: Ember.computed('submittedAt', function() {
    let dateSubmitted = moment(this.get('paper').get('submittedAt'));
    let dateChanged = moment('February 1, 2017');
    return dateSubmitted < dateChanged;
  })
});

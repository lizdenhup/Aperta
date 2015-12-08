import Ember from 'ember';

export default Ember.Component.extend({
  viewingBool: null,
  comparisonBool: null,

  boolText(bool) {
console.log("hi", bool);
    if (bool) {
      return 'Yes';
    } else {
      return 'No';
    }
  },

  viewingBoolText: Ember.computed('viewingBool', function() {
    return this.boolText(this.get('viewingBool'));
  }),

  comparisonBoolText: Ember.computed('comparisonBool', function() {
    return this.boolText(this.get('comparisonBool'));
  })
});

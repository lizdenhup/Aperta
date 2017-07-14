import Ember from 'ember';
import { PropTypes } from 'ember-prop-types';

export default Ember.Component.extend({
  classNames: ['card-content-dropdown'],
  attributeBindings: ['isRequired:required', 'aria-required'],
  'aria-required': Ember.computed.reads('isRequiredString'),

  propTypes: {
    content: PropTypes.EmberObject.isRequired,
    disabled: PropTypes.bool,
    answer: PropTypes.EmberObject.isRequired
  },

  selectedValue: Ember.computed(
    'answer.value',
    'content.possibleValues',
    function() {
      return this.get('content.possibleValues').findBy(
        'value',
        this.get('answer.value')
      );
    }
  ),

  isRequiredString: Ember.computed('isRequired', function() {
    return this.get('isRequired') === true ? 'true' : 'false';
  }),

  init() {
    this._super(...arguments);

    Ember.assert(
      `the content must define an array of possibleValues
      that contains at least one object with the shape { label, value } `,
      Ember.isPresent(this.get('content.possibleValues'))
    );
  },

  actions: {
    valueChanged(newVal) {
      let action = this.get('valueChanged');
      if (action) {
        action(Ember.get(newVal, 'value'));
      }
    }
  }
});

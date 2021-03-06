/**
 * Copyright (c) 2018 Public Library of Science
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
*/

import Ember from 'ember';
import { PropTypes } from 'ember-prop-types';
import QAIdent from 'tahi/mixins/components/qa-ident';

export default Ember.Component.extend(QAIdent, {
  classNames: ['card-content', 'card-content-if'],

  propTypes: {
    content: PropTypes.EmberObject.isRequired,
    disabled: PropTypes.bool,
    owner: PropTypes.EmberObject.isRequired,
    repetition: PropTypes.oneOfType([PropTypes.null, PropTypes.EmberObject]).isRequired,
    preview: PropTypes.bool
  },

  scenario: null,
  hasElse: Ember.computed.equal('content.children.length', 2),

  /**
   * The 'if' component will look up a given key on the 'scenario' that is passed to it.
   * We can't statically know the value of the that key, we can't use a standard computed property.
   * One option is to use 'this.defineProperty' to define a computed property in init() with a dynamic key.
   * The other option is to use an observer. In this case I thought that the observer-based implementation would be
   * easier to reason about and require less ember knowledge than using 'defineProperty'
   */
  init() {
    this._super(...arguments);
    let preview = this.get('preview');
    if (!preview) {
      let conditionName = this.get('conditionName');
      let conditionKey = `scenario.${conditionName}`;
      this.getConditionValue();
      this.addObserver(conditionKey, function() {
        Ember.run(() => {
          this.getConditionValue();
        });
      });
    }
  },

  getConditionValue() {
    let conditionName = this.get('conditionName');
    let scenario = this.get('scenario');
    let value = Ember.get(scenario, conditionName);
    this.set('previousConditionValue', this.get('conditionValue'));
    this.set('conditionValue', value);
  },

  previewState: true,
  conditionName: Ember.computed.reads('content.condition'),
  conditionValue: null,
  previousConditionValue: null,

  condition: Ember.computed(
    'content.condition',
    'preview',
    'previewState',
    'conditionValue',
    function() {
      if (this.get('preview')) {
        return this.get('previewState');
      } else {
        return this.get('conditionValue');
      }
    }
  ),

  pruneOldAnswers: Ember.observer('conditionValue', function() {
    if(this.get('preview')) { return; }

    Ember.run(this, function() {
      let presentValue = this.get('conditionValue');
      let previousValue = this.get('previousConditionValue');
      if(presentValue === previousValue) {
        // Ember Observers will be called any time `conditionValue` is _set_, not
        // just when the value actually changes.  This means we need to track the
        // previous value ourselves to know when the value is toggled and we
        // actually need to destroy the old answers.
        return;
      }

      let owner = this.get('owner');
      let content = this.get('content');
      let repetition = this.get('repetition');

      let branchToPrune;
      if(previousValue === null) {
        return;
      } else if(previousValue) {
        branchToPrune = content.get('children.firstObject');
      } else if (this.get('hasElse')) {
        branchToPrune = content.get('children.lastObject');
      } else {
        return; // the else branch doesn't exist, so there's no answers to delete.
      }

      branchToPrune.destroyDescendants(owner, repetition);
    });
  }),

});

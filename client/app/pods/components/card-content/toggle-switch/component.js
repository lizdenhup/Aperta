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
  classNames: ['card-content', 'card-content-toggle-switch'],
  propTypes: {
    content: PropTypes.oneOfType([PropTypes.object, PropTypes.EmberObject]).isRequired,
    disabled: PropTypes.bool,
    labelText: PropTypes.string,
    interiorText: PropTypes.string,
    answer: PropTypes.oneOfType([PropTypes.object, PropTypes.EmberObject]).isRequired,
    size: PropTypes.string, // 'smaller', small', 'medium', or 'large'
    color: PropTypes.string // 'green', 'blue'
  },

  getDefaultProps() {
    return {
      size: 'medium',
      color: 'green'
    };
  },

  // Note that card-content/toggle switch only consumes the 'ident'
  // on its content
  name: Ember.computed('content.ident', function() {
    let ident = this.get('content.ident') || Ember.guidFor(this);

    return `toggle-switch-${ident}`;
  }),

  actions: {
    valueChanged(newVal) {
      let action = this.get('valueChanged');
      if (action) {
        action(newVal.checked);
      }
    }
  }
});

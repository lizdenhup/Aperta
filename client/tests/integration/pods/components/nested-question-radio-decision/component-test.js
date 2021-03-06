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

import {
  moduleForComponent,
  test
} from 'ember-qunit';
import registerCustomAssertions from 'tahi/tests/helpers/custom-assertions';
import Ember from 'ember';
import hbs from 'htmlbars-inline-precompile';

moduleForComponent('nested-question-radio', 'Integration | Component | nested question radio decision', {
  integration: true,
  beforeEach() {
    registerCustomAssertions();
  }
});

test('shows help text in disabled state', function(assert) {
  const fakeQuestion = Ember.Object.create({
    ident: 'foo',
    additionalData: [{}],
    text: 'Test Question',
    answerForOwner: function () { return Ember.Object.create(); },
    save() { return null; },
  });

  this.set('task', Ember.Object.create({
    findQuestion: function () { return fakeQuestion; }
  }));

  this.render(hbs`{{nested-question-radio-decision ident="foo" owner=task helpText="Something helpful" unwrappedHelpText="Something helpfuls" disabled=true}}`);
  assert.textPresent('.question-help', 'Something helpful');
  assert.textPresent('div', 'Something helpfuls');
});

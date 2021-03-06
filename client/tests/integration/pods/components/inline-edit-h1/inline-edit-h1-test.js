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

import hbs from 'htmlbars-inline-precompile';
import { test, moduleForComponent } from 'ember-qunit';

let template = hbs`{{inline-edit-h1 title=title canManage=canManage setTitle=setTitle}}`;
const title = 'Adhoc For Staff';
const sampleText = 'Adhoc For Paper Submission';

moduleForComponent('inline-edit-h1', 'Integration | Component | inline edit h1', {
  integration: true,
  beforeEach() {
    this.set('title', title);
    this.set('setTitle', 'setTitle');

    this.render(template);
  }
});

test('cannot edit title when canManage=false', function(assert) {
  this.set('canManage', false);

  assert.equal(this.$('h1').text().trim(), title, 'displays the correct header');
  assert.equal(this.$('.button-secondary').text().trim(), 'Save', 'displays the save button');
  assert.equal(this.$('.button-link').text().trim(), 'Cancel', 'displays the cancel button');
  assert.elementNotFound('.inline-edit-icon');
});

test('can edit title when canManage=true', function(assert) {
  this.set('canManage', true);
  //check that the edit icon is displayed
  assert.elementFound('.inline-edit-icon');

  this.$('.inline-edit-icon').click();
  //check that the edit form is displayed
  assert.elementFound('.inline-edit-form');
  assert.elementFound('.title--test');
});

test('clicking save retains a the new title', function(assert) {
  this.set('canManage', true);

  const start = assert.async();
  this.set('setTitle', () => {
    this.set('title', sampleText);
    assert.equal(this.$('h1').text().trim(), sampleText, 'changes title after save button is clicked');
    start();
  });

  this.$('.inline-edit-icon').click();
  //fill form and click save button
  this.$('.title--test').val(sampleText);
  this.$('.button-secondary').click();
});

test('clicking the cancel button while editing retains the previous title', function(assert) {
  this.set('canManage', true);

  this.$('.inline-edit-icon').click();
  //fill form and click cancel button
  this.$('.title--test').val(sampleText);
  this.$('.button-link').click();
  assert.equal(this.$('h1').text().trim(), title, 'retains title when cancel button is clicked');
});

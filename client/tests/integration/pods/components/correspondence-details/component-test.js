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

import { test, moduleForComponent } from 'ember-qunit';
import { make, manualSetup } from 'ember-data-factory-guy';
import FakeCanService from 'tahi/tests/helpers/fake-can-service';
import hbs from 'htmlbars-inline-precompile';

moduleForComponent('correspondence', 'Integration | Component | Correspondence Details', {
  integration: true,

  beforeEach() {
    manualSetup(this.container);
  },
});

test('shows the history if there are activities', function(assert) {
  let paper = make('paper');
  let correspondence = make('correspondence', 'externalCorrespondence', {
    activities: [
      { key: 'correspondence.created', full_name: 'Jim', created_at: '1989-8-19' }
    ],
    paper: paper
  });
  const can = FakeCanService.create().allowPermission('manage_workflow', paper);
  this.register('service:can', can.asService());

  this.set('correspondence', correspondence);
  this.render(hbs`{{correspondence-details message=correspondence}}`);
  assert.textPresent('.history-heading', 'History');
  assert.textPresent('.history-entry', 'Added by Jim');
});

test('shows the last activity', function(assert) {
  const paper = make('paper');
  const correspondence = make('correspondence', 'externalCorrespondence', {
    activities: [
      { key: 'correspondence.edited', full_name: 'John Doe', created_at: '1999-10-11' },
      { key: 'correspondence.created', full_name: 'Jim', created_at: '1989-8-19' }
    ],
    paper: paper
  });
  const can = FakeCanService.create().allowPermission('manage_workflow', paper);
  this.register('service:can', can.asService());

  this.set('correspondence', correspondence);
  this.render(hbs`{{correspondence-details message=correspondence}}`);

  assert.textPresent('.history-text', 'Edited by John Doe');
});

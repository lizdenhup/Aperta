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
import Factory from 'tahi/tests/helpers/factory';
import wait from 'ember-test-helpers/wait';
import hbs from 'htmlbars-inline-precompile';
import { moduleForComponent, test } from 'ember-qunit';
import { manualSetup, make, makeList } from 'ember-data-factory-guy';
import {getRichText} from 'tahi/tests/helpers/rich-text-editor-helpers';

moduleForComponent(
  'register-decision-task',
  'Integration | Components | Tasks | Register Decision', {
    integration: true,

    beforeEach() {
      manualSetup(this.container);
      let nestedQuestions = makeList('nested-question',
                                     { id: 1, ident: 'register_decision_questions--to-field' },
                                     { id: 2, ident: 'register_decision_questions--subject-field' },
                                     { id: 3, ident: 'register_decision_questions--selected-template' });

      let decisions = makeList('decision', 'draft', { verdict: 'accept' }, { verdict: 'minor_revision' });
      let paper = make('paper', {
        journal: {
          id: 1,
          staffEmail: 'staffpeople@example.org'
        },
        publishingState: 'submitted',
        decisions: decisions,
        title: 'GREAT TITLE',
        creator: {
          id: 5,
          lastName: 'Jones',
          email: 'author@example.com'
        }
      });

      let task = make('register-decision-task', {
        paper: paper,
        letterTemplates: [
          {
            id: 1,
            name: 'RA Accept',
            category: 'accept',
            to: '[AUTHOR EMAIL]',
            subject: 'Your [JOURNAL NAME] Submission',
            body: 'Dear Dr. [LAST NAME],Regarding [PAPER TITLE] in [JOURNAL NAME] for [JOURNAL STAFF EMAIL] Sincerely Someone who Accepts' },
          {
            id: 2,
            name: 'Editor Reject',
            category: 'reject',
            to: '[AUTHOR EMAIL]',
            subject: 'Your [JOURNAL NAME] Submission',
            body: 'Dear Dr. [LAST NAME],Regarding [PAPER TITLE] in [JOURNAL NAME] Sincerely who Rejects' }],
        nestedQuestions: nestedQuestions
      });

      // Mock out pusher
      this.registry.register('service:pusher', Ember.Object.extend({socketId: 'foo'}));

      Factory.createPermission('registerDecisionTask', 1, ['edit', 'view']);

      this.set('task', task);

      $.mockjax({url: /api\/nested_questions\/1\/answers/, type: 'PUT', status: 204, responseText: '[]'});
      $.mockjax({url: '/api/nested_questions/1/answers', type: 'POST', status: 201, responseText: {nested_question_answer: {id: 1}}});
      $.mockjax({url: /api\/nested_questions\/2\/answers/, type: 'PUT', status: 204, responseText: '[]'});
      $.mockjax({url: '/api/nested_questions/2/answers', type: 'POST', status: 201, responseText: {nested_question_answer: {id: 2}}});
      $.mockjax({url: /api\/nested_questions\/3\/answers/, type: 'PUT', status: 204, responseText: '[]'});
      $.mockjax({url: '/api/nested_questions/3/answers', type: 'POST', status: 201, responseText: {nested_question_answer: {id: 3}}});
      $.mockjax({url: /\/api\/decisions\/[0-9]+/, type: 'PUT', status: 204, responseText: '[]'});

      this.selectDecision = function(decision) {
        this.$(`label:contains('${decision}') input[type='radio']`).first().click();
      };

      this.select2 = function(choice) {
        Ember.run(()=>{
          let input = this.$('.select2-container input');
          input.trigger('keydown');
          input.val(choice);
          input.trigger('keyup');
          $('.select2-result-selectable').trigger('mouseup');
        });
      };

      this.render(hbs`{{register-decision-task task=task container=container}}`);
    }
  }
);

function compareText(assert, field, regex) {
  let text = getRichText('decision-letter-field');
  assert.ok(regex.test(text), 'text matches');
}

test('it renders decision selections', function(assert) {
  assert.elementsFound('.decision-label', 4);
  this.selectDecision('Accept');
  this.select2('RA Accept');
  return wait().then(()=>{
    compareText(assert, 'decision-letter-field', /Dear/);
  });
});

test('it does not update the letter contents on change of verdict unless template selection made', function(assert) {
  this.selectDecision('Accept');
  this.select2('RA Accept');
  return wait().then(()=>{
    compareText(assert, 'decision-letter-field', /who Accepts/);
    this.selectDecision('Reject');
    return wait().then(()=>{
      compareText(assert, 'decision-letter-field', /who Accepts/);
    });
  });
});

test('it switches the letter contents on change', function(assert) {
  this.selectDecision('Accept');
  this.select2('RA Accept');
  return wait().then(()=>{
    compareText(assert, 'decision-letter-field', /who Accepts/);
    this.selectDecision('Reject');
    return wait().then(()=>{
      this.select2('Editor Reject');
      return wait().then(()=>{
        compareText(assert, 'decision-letter-field', /who Rejects/);
      });
    });
  });
});

['unsubmitted', 'in_revision', 'invited_for_full_submission', 'accepted', 'rejected'].forEach((state)=>{
  test(`when the paper is ${state}, do not show register stuff`, function(assert) {
    this.set('task', make('register-decision-task', {
      'paper': { 'publishingState': state }
    }));
    assert.textPresent('.task-main-content', 'A decision cannot be registered at this time');
  });
});

test('User has the ability to rescind', function(assert){
  assert.elementFound(
    '.rescind-decision',
    'User sees the rescind decision bar'
  );
});

test('User can see the decision history', function(assert){
  assert.nElementsFound(
    '.decision-bar',
    2,
    'User sees only completed decisions'
  );
});

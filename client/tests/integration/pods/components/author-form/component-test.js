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
import {moduleForComponent, test} from 'ember-qunit';
import FactoryGuy from 'ember-data-factory-guy';
import { manualSetup } from 'ember-data-factory-guy';
import { createQuestionWithAnswer } from 'tahi/tests/factories/nested-question';
import * as TestHelper from 'ember-data-factory-guy';
import FakeCanService from 'tahi/tests/helpers/fake-can-service';
import registerCustomAssertions from 'tahi/tests/helpers/custom-assertions';

import hbs from 'htmlbars-inline-precompile';

let journal, template;

moduleForComponent(
  'author-form',
  'Integration | Component | author-form',
  {
    integration: true,
    beforeEach: function() {
      manualSetup(this.container);
      registerCustomAssertions();

      $.mockjax({url: '/api/countries', status: 200, responseText: {
        countries: []
      }});
      $.mockjax({url: '/api/institutional_accounts', status: 200, responseText: {
        institutional_accounts: []
      }});

      journal = FactoryGuy.make('journal');
      TestHelper.mockFindRecord('journal').returns({model: journal});

      let user = FactoryGuy.make('user');
      let task = FactoryGuy.make('authors-task');
      let author = FactoryGuy.make('author', { user: user });
      let paper = FactoryGuy.make('paper');

      this.set('author', author);
      this.set('author.paper', paper);
      this.set('author.paper.journal', journal);
      this.set('isNotEditable', false);
      this.set('model', Ember.ObjectProxy.create({object: author}));
      this.set('task', task);

      this.set("toggleEditForm", () => {});
      this.set("validateField", () => {});
      this.set("canRemoveOrcid", true);

      createQuestionWithAnswer(author, 'author--published_as_corresponding_author', true);
      createQuestionWithAnswer(author, 'author--deceased', false);
      createQuestionWithAnswer(author, 'author--government-employee', false);
      createQuestionWithAnswer(author, 'author--contributions--conceptualization', false);
      createQuestionWithAnswer(author, 'author--contributions--investigation', false);
      createQuestionWithAnswer(author, 'author--contributions--visualization', false);
      createQuestionWithAnswer(author, 'author--contributions--methodology', false);
      createQuestionWithAnswer(author, 'author--contributions--resources', false);
      createQuestionWithAnswer(author, 'author--contributions--supervision', false);
      createQuestionWithAnswer(author, 'author--contributions--software', false);
      createQuestionWithAnswer(author, 'author--contributions--data-curation', false);
      createQuestionWithAnswer(author, 'author--contributions--project-administration', false);
      createQuestionWithAnswer(author, 'author--contributions--validation', false);
      createQuestionWithAnswer(author, 'author--contributions--writing-original-draft', false);
      createQuestionWithAnswer(author, 'author--contributions--writing-review-and-editing', false);
      createQuestionWithAnswer(author, 'author--contributions--funding-acquisition', false);
      createQuestionWithAnswer(author, 'author--contributions--formal-analysis', false);
    }
  }
);

template = hbs`
  {{author-form
      author=model.object
      authorProxy=model
      validateField=(action validateField)
      hideAuthorForm="toggleEditForm"
      isNotEditable=isNotEditable
      saveSuccess=(action toggleEditForm)
      canRemoveOrcid=true
      coauthorConfirmationEnabled=true
      authorIsPaperCreator=true
  }}`;

test("component displays the orcid-connect component when the author has an orcidAccount", function(assert){
  const can = FakeCanService.create().allowPermission('manage_paper_authors', this.get('author.paper'));
  this.register('service:can', can.asService());
  let orcidAccount = FactoryGuy.make('orcid-account');
  Ember.run( () => {
    this.get("author.user").set("orcidAccount", orcidAccount);
  });
  this.render(template);
  assert.elementFound(".orcid-connect");
});

test("component does not display the orcid-connect component when the author does not have an orcidAccount", function(assert){
  const can = FakeCanService.create().allowPermission('manage_paper_authors', this.get('author.paper'));
  this.register('service:can', can.asService());
  Ember.run( () => {
    this.get("author.user").set("orcidAccount", null);
  });
  this.render(template);
  assert.elementNotFound(".orcid-wrapper");
});

test('component shows coauthor controls when user is considered a paper-manager user', function(assert){
  template = hbs`
  {{author-form
      author=model.object
      authorProxy=model
      validateField=(action validateField)
      hideAuthorForm="toggleEditForm"
      isNotEditable=isNotEditable
      saveSuccess=(action toggleEditForm)
      canRemoveOrcid=true
      coauthorConfirmationEnabled=true
      authorIsPaperCreator=false
  }}`;

  Ember.run(() => {
    const can = FakeCanService.create().allowPermission('manage_paper_authors', this.get('author.paper'));
    this.register('service:can', can.asService());
  });

  this.render(template);
  assert.elementFound('[data-test-selector="coauthor-radio-controls"]');
});

test('component hides coauthor controls when user is considered an non-paper-manager user', function(assert){
  template = hbs`
  {{author-form
      author=model.object
      authorProxy=model
      validateField=(action validateField)
      hideAuthorForm="toggleEditForm"
      isNotEditable=isNotEditable
      saveSuccess=(action toggleEditForm)
      canRemoveOrcid=true
      coauthorConfirmationEnabled=true
      authorIsPaperCreator=false
  }}`;
  Ember.run(() => {
    const can = FakeCanService.create().rejectPermission('manage_paper_authors', this.get('author.paper'));
    this.register('service:can', can.asService());
  });

  this.render(template);
  assert.elementNotFound('[data-test-selector="coauthor-radio-controls"]');
});

test('component hides coauthor controls if the setting is disabled', function(assert){
  template = hbs`
  {{author-form
      author=model.object
      authorProxy=model
      validateField=(action validateField)
      hideAuthorForm="toggleEditForm"
      isNotEditable=isNotEditable
      saveSuccess=(action toggleEditForm)
      canRemoveOrcid=true
      coauthorConfirmationEnabled=false
      authorIsPaperCreator=false
  }}`;

  Ember.run(() => {
    const can = FakeCanService.create().allowPermission('manage_paper_authors', this.get('author.paper'));
    this.register('service:can', can.asService());
  });

  this.render(template);
  assert.elementNotFound('[data-test-selector="coauthor-radio-controls"]');
});

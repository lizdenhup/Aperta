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

import { moduleForComponent, test } from 'ember-qunit';
import hbs from 'htmlbars-inline-precompile';
import FactoryGuy from 'ember-data-factory-guy';
import { manualSetup } from 'ember-data-factory-guy';
import sinon from 'sinon';
import Ember from 'ember';

moduleForComponent(
  'card-content/if',
  'Integration | Component | card content | if then else',
  {
    integration: true,
    beforeEach: function() {
      manualSetup(this.container);
      this.set('repetition', null);
    }
  }
);

let ifTemplate = hbs`
{{card-content/if
  class="if-parent"
  scenario=scenario
  owner=owner
  preview=false
  repetition=repetition
  content=content}}`;

let parent = Ember.Object.extend({
  contentType: 'if',
  condition: 'isEditable',
  text: 'If Parent',
  answerForOwner() {
    return Ember.Object.create({ isEditable: true });
  }
});

test(`if/then/else (2 children) chooses 'then' or 'else' content based on the condition`, function(assert) {
  let content = parent.create({
    children: [
      FactoryGuy.make('card-content', {
        contentType: 'short-input',
        text: 'Child 1'
      }),
      FactoryGuy.make('card-content', {
        contentType: 'paragraph-input',
        text: 'Child 2'
      })
    ]
  });

  this.set('owner', Ember.Object.create());
  this.set('scenario', {});
  this.set('scenario.isEditable', true );
  this.set('content', content);
  this.render(ifTemplate);

  assert.elementFound('.card-content-short-input', 'found then content');

  this.set('scenario.isEditable', false );
  assert.elementFound('.card-content-paragraph-input', 'found else content');
});

test(`if/then (only 1 child) chooses 'then' content or nothing based on the condition`, function(assert) {
  let content = parent.create({
    children: [
      FactoryGuy.make('card-content', {
        contentType: 'short-input',
        text: 'Child 1'
      })
    ]
  });

  this.set('owner', Ember.Object.create());
  this.set('scenario', {});
  this.set('scenario.isEditable', true );
  this.set('content', content);
  this.render(ifTemplate);

  assert.elementFound('.card-content-short-input', 'found then content');

  this.set('scenario.isEditable', false );
  assert.elementNotFound('.card-content-short-input', 'found no content');
});

let cardContentTemplate = hbs`
{{card-content content=content
               scenario=scenario
               preview=preview
               repetition=repetition
               owner=owner}}`;

test(`can reference a scenario from a parent view instead of having it passed in directly`, function(assert) {
  let content = parent.create({
    children: [
      FactoryGuy.make('card-content', {
        contentType: 'short-input',
        text: 'Child 1'
      }),
      FactoryGuy.make('card-content', {
        contentType: 'paragraph-input',
        text: 'Child 2'
      })
    ]
  });

  this.set('owner', Ember.Object.create());
  this.set('preview', false);
  this.set('scenario', {});
  this.set('scenario.isEditable', true );
  this.set('content', content);
  this.render(cardContentTemplate);

  assert.elementFound('.card-content-short-input', 'found then content');

  this.set('scenario.isEditable', false );
  assert.elementFound('.card-content-paragraph-input', 'found else content');
});

test(`ignores the scenario when preview is true, and shows a toggle`, function(assert) {
  let content = parent.create({
    children: [
      FactoryGuy.make('card-content', {
        contentType: 'short-input',
        text: 'Child 1'
      }),
      FactoryGuy.make('card-content', {
        contentType: 'paragraph-input',
        text: 'Child 2'
      })
    ]
  });

  this.set('owner', Ember.Object.create());
  this.set('preview', true);
  this.set('content', content);
  this.render(cardContentTemplate);

  assert.elementFound('.if-preview', 'found preview');
});

test(
  `destroy child answers when an if-branch is hidden`,
  function(assert) {
    let template = hbs`
    {{card-content/if
      class="removing-answers-test"
      owner=owner
      scenario=scenario
      preview=false
      disabled=disabled
      repetition=repetition
      content=content}}`;

    let owner = FactoryGuy.make('custom-card-task');

    let content = parent.create({
      children: [
        FactoryGuy.make('card-content', {
          contentType: 'short-input',
          text: 'question then',
          answers: [
            FactoryGuy.make('answer', { owner: owner, value: 'answer then' })
          ]
        }),
        FactoryGuy.make('card-content', {
          contentType: 'paragraph-input',
          text: 'question else',
          answers: [
            FactoryGuy.make('answer', { owner: owner, value: 'answer else' })
          ]
        })
      ]
    });

    let thenAnswer = content.get('children.firstObject.answers.firstObject');
    let elseAnswer = content.get('children.lastObject.answers.firstObject');

    const thenDestroyRecord = sinon.spy();
    thenAnswer.set('destroyRecord', thenDestroyRecord);

    const elseDestroyRecord = sinon.spy();
    elseAnswer.set('destroyRecord', elseDestroyRecord);

    this.set('owner', owner);
    this.set('content', content);
    this.set('scenario', { isEditable: true });
    this.render(template);

    // ensure that "then branch" is shown
    assert.textPresent('.removing-answers-test', 'question then');
    assert.textNotPresent('.removing-answers-test', 'question else');

    // ensure that "else branch" is shown
    this.set('scenario.isEditable', false);
    assert.textNotPresent('.removing-answers-test', 'question then');
    assert.textPresent('.removing-answers-test', 'question else');
    assert.ok(thenDestroyRecord.called, 'destroyRecord was never called on the thenAnswer');

    // ensure that "then branch" is shown
    this.set('scenario.isEditable', true);
    assert.textPresent('.removing-answers-test', 'question then');
    assert.textNotPresent('.removing-answers-test', 'question else');
    assert.ok(elseDestroyRecord.called, 'destroyRecord was never called on the elseAnswer');
  }
);

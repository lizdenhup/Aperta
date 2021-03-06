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
import { moduleForComponent, test } from 'ember-qunit';
import registerCustomAssertions from 'tahi/tests/helpers/custom-assertions';
import { manualSetup, make } from 'ember-data-factory-guy';
import hbs from 'htmlbars-inline-precompile';

moduleForComponent(
  'card-content/repeat',
  'Integration | Component | card content | financial disclosure summary',
  {
    integration: true,
    beforeEach() {
      registerCustomAssertions();
      manualSetup(this.container);
      this.registry.register('pusher:main', Ember.Object.extend({socketId: 'foo'}));
    },

    afterEach() {
      $.mockjax.clear();
    }
  }
);

let template = hbs`{{card-content/financial-disclosure-summary
  content=content
  disabled=false
  owner=owner
  repetition=repetition
  preview=false
}}`;

test('it displays no statement if there are no funders', function(assert) {
  this.set('content', Ember.Object.create());
  this.set('owner', Ember.Object.create({ repetitions: [] }));
  this.set('repetition', null);
  this.render(template);

  assert.textNotPresent('.card-content-financial-disclosure-summary', 'Your Financial Disclosure Statement', 'financial disclosure statement is not displayed');
});

test('it renders the statement when there is one funder', function(assert) {
  let task = make('custom-card-task');
  let cardContent = make('card-content');

  // create funder card content
  let funderNameCardContent = make('card-content', { ident: 'funder--name' });
  let repetition = make('repetition', { task: task, cardContent: [funderNameCardContent] });

  // create funder answers
  make('answer', { owner: task, cardContent: funderNameCardContent, repetition: repetition, value: 'Sally Jones' } );

  this.set('content', cardContent);
  this.set('owner', task);
  this.set('repetition', null);
  this.render(template);

  assert.textPresent('.card-content-financial-disclosure-summary', 'Your Financial Disclosure Statement', 'financial disclosure statement is not displayed');
});

test('it renders just the additional comments if there is not funder data', function(assert) {
  let task = make('custom-card-task');
  let cardContent = make('card-content');

  // create funder card content
  let funderAdditionalCommmentsCardContent = make('card-content', { ident: 'funder--additional_comments' });
  let repetition = make('repetition', { task: task, cardContent: [funderAdditionalCommmentsCardContent] });

  // create funder answers
  make('answer', { owner: task, cardContent: funderAdditionalCommmentsCardContent, repetition: repetition, value: 'I have some comments' } );

  this.set('content', cardContent);
  this.set('owner', task);
  this.set('repetition', null);
  this.render(template);

  assert.textPresent('.card-content-financial-disclosure-summary', 'I have some comments', 'funder comments are displayed');
});

test('it renders funder data', function(assert) {
  let task = make('custom-card-task');
  let cardContent = make('card-content');

  // create funder card content
  let funderAdditionalCommmentsCardContent = make('card-content', { ident: 'funder--additional_comments' });
  let funderNameCardContent = make('card-content', { ident: 'funder--name' });
  let funderGrantNumberCardContent = make('card-content', { ident: 'funder--grant_number' });
  let funderWebsiteCardContent = make('card-content', { ident: 'funder--website' });
  let repetition = make('repetition', { task: task, cardContent: [
    funderAdditionalCommmentsCardContent,
    funderNameCardContent,
    funderGrantNumberCardContent,
    funderWebsiteCardContent
  ] });

  // create funder answers
  make('answer', { owner: task, cardContent: funderAdditionalCommmentsCardContent, repetition: repetition, value: 'I have some comments' } );
  make('answer', { owner: task, cardContent: funderNameCardContent, repetition: repetition, value: 'Sally Jones' } );
  make('answer', { owner: task, cardContent: funderGrantNumberCardContent, repetition: repetition, value: '111-1111' } );
  make('answer', { owner: task, cardContent: funderWebsiteCardContent, repetition: repetition, value: 'http://www.example.com/' } );

  this.set('content', cardContent);
  this.set('owner', task);
  this.set('repetition', null);
  this.render(template);

  assert.textPresent('.card-content-financial-disclosure-summary', 'I have some comments', 'funder comments are displayed');
  assert.textPresent('.card-content-financial-disclosure-summary', 'Sally Jones', 'funder name is displayed');
  assert.textPresent('.card-content-financial-disclosure-summary', '111-1111', 'funder grant number is displayed');
  assert.elementFound('.card-content-financial-disclosure-summary a[href="http://www.example.com/"]', 'funder website link is displayed');
});

test('it renders custom funding statement', function(assert) {
  let task = make('custom-card-task');
  let cardContent = make('card-content');

  // create funder card content
  let funderNameCardContent = make('card-content', { ident: 'funder--name' });
  let funderHadInfluenceCardContent = make('card-content', { ident: 'funder--had_influence--role_description' });
  let repetition = make('repetition', { task: task, cardContent: [
    funderNameCardContent,
    funderHadInfluenceCardContent
  ]});

  // create funder answers
  make('answer', { owner: task, cardContent: funderNameCardContent, repetition: repetition, value: 'Sally Jones' } );
  make('answer', { owner: task, cardContent: funderHadInfluenceCardContent, repetition: repetition, value: 'I had some influence' } );

  this.set('content', cardContent);
  this.set('owner', task);
  this.set('repetition', null);
  this.render(template);

  assert.textPresent('.card-content-financial-disclosure-summary', 'I had some influence', 'funder custom had-influence is displayed');
});

test('it renders default funding statement', function(assert) {
  let task = make('custom-card-task');
  let cardContent = make('card-content');

  // create funder card content
  let funderNameCardContent = make('card-content', { ident: 'funder--name' });
  let repetition = make('repetition', { task: task, cardContent: [
    funderNameCardContent,
  ]});

  // create funder answers
  make('answer', { owner: task, cardContent: funderNameCardContent, repetition: repetition, value: 'Sally Jones' } );

  this.set('content', cardContent);
  this.set('owner', task);
  this.set('repetition', null);
  this.render(template);

  assert.textPresent('.card-content-financial-disclosure-summary', 'The funder had no role in study design', 'funder default had-influence is displayed');
});

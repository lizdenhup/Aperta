import Ember from 'ember';
import { test, moduleForModel } from 'ember-qunit';
import startApp from 'tahi/tests/helpers/start-app';
import FactoryGuy from 'ember-data-factory-guy';
import * as TestHelper from 'ember-data-factory-guy';

var App;

moduleForModel('paper', 'Unit: Paper Model', {
  needs: ['model:author','model:group-author','model:card', 'model:correspondence', 'model:snapshot','model:related-article','model:paper-task-type', 'model:user', 'model:figure', 'model:journal', 'model:decision', 'model:invitation', 'model:affiliation', 'model:attachment', 'model:question-attachment', 'model:comment-look', 'model:discussion-topic', 'model:versioned-text', 'model:discussion-participant', 'model:discussion-reply', 'model:phase', 'model:task', 'model:comment', 'model:participation', 'model:card-thumbnail', 'model:nested-question-owner', 'model:nested-question', 'model:nested-question-answer', 'model:collaboration', 'model:supporting-information-file','model:similarity-check'],
  afterEach: function() {
    Ember.run(function() {
      return TestHelper.mockTeardown();
    });
    return Ember.run(App, "destroy");
  },
  beforeEach: function() {
    App = startApp();
    return TestHelper.mockSetup();
  }
});

test('displayTitle displays [NO TITLE] if title is missing', function(assert) {
  var shortTitle;
  shortTitle = 'test short title';
  var paper = FactoryGuy.make("paper", {
    title: "",
    shortTitle: shortTitle
  });
  assert.equal(paper.get('displayTitle'), "[No Title]");
});

test('displayTitle displays title if present', function(assert) {
  var title;
  title = 'Test Title';
  var paper = FactoryGuy.make("paper", {
    title: title,
    shortTitle: ""
  });
  assert.equal(paper.get('displayTitle'), title);
});

test('previousDecisions returns decisions that are not drafts', function(assert){
  var noVerdictDecision = FactoryGuy.make('decision', 'draft');
  var acceptedDecision = FactoryGuy.make('decision');
  var rejectedDecision = FactoryGuy.make('decision');

  var paper = FactoryGuy.make('paper', {
    decisions: [noVerdictDecision, acceptedDecision, rejectedDecision]
  });

  assert.arrayContainsExactly(
    paper.get('previousDecisions'),
    [acceptedDecision, rejectedDecision]
  );
});

test('simplifiedRelatedUsers contains no collaborators', function(assert) {
  var title;
  title = 'Test Title';
  var paper = FactoryGuy.make('paper', {
    title: title,
    shortTitle: '',
    relatedUsers: [
      {name: 'Creator', users: []},
      {name: 'Collaborator', users: []}
    ]
  });
  assert.equal(paper.get('simplifiedRelatedUsers.length'), 1);
  let remaining = paper.get('simplifiedRelatedUsers').objectAt(0).name;
  assert.equal(remaining, 'Creator');
});

['accepted',
  'in_revision',
  'invited_for_full_submission',
  'published',
  'rejected',
  'unsubmitted',
  'withdrawn'].forEach((state)=>{
    test(`isReadyForDecision is false when publishingState is ${state}`, (assert)=>{
      let paper = FactoryGuy.make('paper', { publishingState: state });
      assert.notOk(paper.get('isReadyForDecision'));
    });
  });


['submitted', 'initially_submitted', 'checking'].forEach((state)=>{
  test(`isReadyForDecision is true when publishingState is ${state}`, (assert)=>{
    let paper = FactoryGuy.make('paper', { publishingState: state });
    assert.ok(paper.get('isReadyForDecision'));
  });
});

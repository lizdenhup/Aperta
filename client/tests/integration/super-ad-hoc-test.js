import Ember from 'ember';
import { module, test } from 'qunit';
import startApp from 'tahi/tests/helpers/start-app';
import setupMockServer from '../helpers/mock-server';
import { paperWithTask } from '../helpers/setups';
import Factory from '../helpers/factory';
import FactoryGuy from 'ember-data-factory-guy';
import { make } from 'ember-data-factory-guy';
import TestHelper from 'ember-data-factory-guy/factory-guy-test-helper';

let App = null;
let server = null;
let fakeUser = null;
let currentPaper = null;

const { mockFind } = TestHelper;

const paperTaskURL = function paperTaskURL(paper, task) {
  return '/papers/' + paper.get('id') + '/tasks/' + task.get('id');
};

module('Integration: Super AdHoc Card', {
  afterEach() {
    server.restore();
    Ember.run(function() { TestHelper.teardown(); });
    Ember.run(App, App.destroy);
  },

  beforeEach() {
    App      = startApp();
    server   = setupMockServer();
    fakeUser = window.currentUserData.user;

    TestHelper.handleFindAll('discussion-topic', 1);

    let records = paperWithTask('Task', {
      id: 1,
      type: 'AdHocTask',
      title: 'Super Ad-Hoc'
    });

    currentPaper = records[0];

    let paperPayload = Factory.createPayload('paper');
    paperPayload.addRecords(records.concat([fakeUser]));

    let paperResponse = paperPayload.toJSON();
    let collaborators = [
      {
        id: '35',
        full_name: 'Aaron Baker',
        info: 'testroles2, collaborator'
      }
    ];

    server.respondWith('GET', '/api/dashboards', [
      200, {
        'Content-Type': 'application/json'
      }, JSON.stringify({
        dashboards: []
      })
    ]);

    server.respondWith('GET', '/api/papers/' + currentPaper.id, [
      200, {
        'Content-Type': 'application/json'
      }, JSON.stringify(paperResponse)
    ]);

    server.respondWith('PUT', /\/api\/tasks\/\d+/, [
      204, {
        'Content-Type': 'application/json'
      }, JSON.stringify({})
    ]);

    server.respondWith('GET', '/api/tasks/1/nested_questions', [
      200, {
        'Content-Type': 'application/json'
      }, JSON.stringify({nested_questions: []})
    ]);

    server.respondWith('GET', '/api/tasks/1/nested_question_answers', [
      200, {
        'Content-Type': 'application/json'
      }, JSON.stringify({nested_question_answers: []})
    ]);

    server.respondWith('GET', "/api/journals", [200, { 'Content-Type': 'application/json' }, JSON.stringify({journals:[]})]);

    $.mockjax({
      url: '/api/countries',
      status: 200,
      responseText: []
    });
  }
});

test('Changing the title on an AdHoc Task', function(assert) {
  const paper = make('paper');
  const task  = make('ad-hoc-task', { paper: paper });

  mockFind('paper').returns({ model: paper });
  mockFind('task').returns({ model: task });

  visit(paperTaskURL(paper, task));
  click('h1.inline-edit .fa-pencil');
  fillIn('.large-edit input[name=title]', 'Shazam!');
  click('.large-edit .button--green:contains("Save")');

  andThen(function() {
    assert.elementFound('h1.inline-edit:contains("Shazam!")',
                        'title is changed');
  });
});

test('AdHoc Task text block', function(assert) {
  let paper = make('paper');
  let task  = make('ad-hoc-task', { paper: paper, body: [] });

  mockFind('paper').returns({ model: paper });
  mockFind('task').returns({ model: task });

  visit(paperTaskURL(paper, task));
  click('.adhoc-content-toolbar .fa-plus');
  click('.adhoc-content-toolbar .adhoc-toolbar-item--text').then(function() {
    assert.elementFound('.inline-edit-body-part',
                        'New text body part is created');

    Ember.$('.inline-edit-form div[contenteditable]')
         .html('New contenteditable, yahoo!')
         .trigger('keyup');

    click('.inline-edit-body-part .button--green:contains("Save")');
  });

  andThen(function() {
    assert.textPresent('.inline-edit', 'yahoo');
    click('.inline-edit-body-part .fa-trash');
  });

  andThen(function() {
    assert.textPresent('.inline-edit-body-part', 'Are you sure?');
    click('.inline-edit-body-part .delete-button');
  });

  andThen(function() {
    assert.textNotPresent('.inline-edit', 'yahoo');
  });
});

test('AdHoc Task list block', function(assert) {
  const paper = make('paper');
  const task  = make('ad-hoc-task', { paper: paper, body: [] });

  mockFind('paper').returns({ model: paper });
  mockFind('task').returns({ model: task });

  visit(paperTaskURL(paper, task));

  click('.adhoc-content-toolbar .fa-plus');
  click('.adhoc-content-toolbar .adhoc-toolbar-item--list').then(function() {
    assert.elementFound('.inline-edit-body-part',
                        'New list body part is created');

    Ember.$('.inline-edit-form label[contenteditable]')
         .html('Here is a checkbox list item')
         .trigger('keyup');

    click('.inline-edit-body-part .button--green:contains("Save")');
  });

  andThen(function() {
    assert.textPresent('.inline-edit', 'checkbox list item');
    assert.elementFound('.inline-edit input[type=checkbox]',
                        'checkbox item is visble');

    click('.inline-edit-body-part .fa-trash');
  });

  andThen(function() {
    assert.textPresent('.inline-edit-body-part', 'Are you sure?');
    click('.inline-edit-body-part .delete-button');
  });

  andThen(function() {
    assert.textNotPresent('.inline-edit', 'checkbox list item');
  });
});

test('AdHoc Task email block', function(assert) {
  const paper = make('paper');
  const task  = make('ad-hoc-task', { paper: paper, body: [] });

  mockFind('paper').returns({ model: paper });
  mockFind('task').returns({ model: task });

   server.respondWith('PUT', /\/api\/tasks\/\d+\/send_message/, [
     204, {
       'Content-Type': 'application/json'
     }, JSON.stringify({})
   ]);

  visit(paperTaskURL(paper, task));

  click('.adhoc-content-toolbar .fa-plus');
  click('.adhoc-content-toolbar .adhoc-toolbar-item--email');

  fillIn(
    '.inline-edit-form input[placeholder="Enter a subject"]',
    'Deep subject'
  ).then(function() {
    Ember.$('.inline-edit-form div[contenteditable]')
         .html('Awesome email body!')
         .trigger('keyup');

    click('.task-body .inline-edit-body-part .button--green:contains("Save")');
  });

  andThen(function() {
    assert.textPresent('.inline-edit .item-subject', 'Deep');
    assert.textPresent('.inline-edit .item-text', 'Awesome');

    click('.task-body .inline-edit-body-part .button--green:contains("Save")');
    click('.task-body .email-send-participants');
    click('.send-email-action');
  });

  andThen(function() {
    assert.elementFound('.bodypart-last-sent',
                        'The sent at time should appear');
    assert.elementFound('.bodypart-email-sent-overlay',
                        'The sent confirmation should appear');

    assert.ok(_.findWhere(server.requests, {
      method: 'PUT',
      url: '/api/tasks/1/send_message'
    }), 'It posts to the server');
  });
});

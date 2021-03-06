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
import Ember from 'ember';
import { manualSetup, make, mockUpdate } from 'ember-data-factory-guy';
import Factory from 'tahi/tests/helpers/factory';
import FakeCanService from 'tahi/tests/helpers/fake-can-service';
import wait from 'ember-test-helpers/wait';

let emberContainer;

let createTaskWithFiles = function(files) {
  return make('supporting-information-task', {
    paper: {
      id: 1,
      supportingInformationFiles: files
    }
  });
};

let allowPermissionOnTask = function(permission, task){
  let fakeCanService = emberContainer.lookup('service:can');
  fakeCanService.allowPermission('edit', task);
};

moduleForComponent(
  'supporting-information-task',
  'Integration | Components | Tasks | Supporting Information', {
  integration: true,
  beforeEach() {
    manualSetup(this.container);
    $.mockjax.clear();

    this.registry.register('service:pusher', Ember.Object.extend({socketId: 'foo'}));
    this.registry.register('service:can', FakeCanService);

    emberContainer = this.container;
  },
  afterEach() {
    $.mockjax.clear();
  }
});

let template = hbs`{{supporting-information-task task=testTask}}`;

test("it renders the paper's supportingInformationFiles", function(assert) {
  let testTask = createTaskWithFiles([
    make('supporting-information-file', {title: 'SI File. 1', id: 1})
  ]);
  this.set('testTask', testTask);
  this.render(template);

  return wait().then(() => {
    assert.elementsFound('.si-file', 1);
  });
});

test('it reports validation errors on the task when attempting to complete', function(assert) {
  let testTask = createTaskWithFiles([
    make('supporting-information-file', {label: null, id: 1})
  ]);
  allowPermissionOnTask('edit', testTask);
  this.set('testTask', testTask);

  this.render(template);
  assert.elementsFound('.si-file', 1);
  this.$('.supporting-information-task button.task-completed').click();

  return wait().then(() => {
    // Error at the task level
    assert.textPresent('.supporting-information-task', 'Please fix all errors');
    assert.equal(testTask.get('completed'), false, 'task remained incomplete');
  });
});

test('it retains validation errors on the remaining files when a file is deleted', function(assert) {
  let testTask = createTaskWithFiles([
    make('supporting-information-file', {label: null, status: 'done', id: 1}),
    make('supporting-information-file', {label: null, status: 'done', id: 2})
  ]);
  allowPermissionOnTask('edit', testTask);
  this.set('testTask', testTask);

  this.render(template);
  assert.elementsFound('.si-file-viewing', 2);

  this.$('.si-file-viewing .si-file-edit-icon').first().click();
  assert.elementsFound('.si-file-viewing', 1);
  assert.elementsFound('.si-file-editor', 1);

  // Validation errors are visible on the first file
  this.$('.si-file-editor .si-file-save-edit-button').click();
  assert.textPresent('.si-file-editor', 'Please edit and complete the required fields');

  // delete the second file
  $.mockjax({url: '/api/supporting_information_files/2', type: 'DELETE', status: 204, responseText: ''});
  this.$('.si-file-viewing .si-file-delete-icon').click();
  this.$('.si-file-viewing .si-file-delete-button').click();

  return wait().then(() => {
    // Validation errors remain visible on the first (and now only) file
    assert.textPresent('.si-file-editor', 'Please edit and complete the required fields');
    assert.elementNotFound('.si-file-viewing');
  });
});

test('it requires validation on an SI file label', function(assert) {
  let testTask = createTaskWithFiles([
    make('supporting-information-file', {label: null, id: 1, status: 'done'})
  ]);
  allowPermissionOnTask('edit', testTask);
  this.set('testTask', testTask);
  this.render(template);
  this.$('.supporting-information-task button.task-completed').click();

  return wait().then(() => {
    assert.elementFound('.si-file .error-message:not(.error-message--hidden)');
    assert.textPresent('.si-file .error-message', 'Please edit');
    assert.equal(testTask.get('completed'), false, 'task remained incomplete');
  });
});

test('it requires validation on an SI file category', function(assert) {
  let testTask = createTaskWithFiles([
    make('supporting-information-file', {category: null, status: 'done', id: 1})
  ]);
  allowPermissionOnTask('edit', testTask);
  this.set('testTask', testTask);
  this.render(template);
  this.$('.supporting-information-task button.task-completed').click();

  return wait().then(() => {
    assert.elementFound('.si-file .error-message:not(.error-message--hidden)');
    assert.textPresent('.si-file .error-message', 'Please edit');
    assert.equal(testTask.get('completed'), false, 'task remained incomplete');
  });
});

test("it allows completion when all the files have a status of 'done'", function(assert) {
  let file = make('supporting-information-file', { status: 'done' });
  let testTask = createTaskWithFiles([file]);
  allowPermissionOnTask('edit', testTask);
  this.set('testTask', testTask);
  let testUrl = `/api/tasks/${testTask.id}`;
  $.mockjax({url: testUrl, type: 'PUT', status: 204, responseText: '{}'});

  this.render(template);

  this.$('.task-completed').click();
  return wait().then(() => {
    assert.equal(testTask.get('completed'), true, 'task is completed');
    assert.mockjaxRequestMade(testUrl, 'PUT', 'it saves the task')
  });
});

test('it does not allow the user to complete when there are validation errors', function(assert) {
  let testTask = createTaskWithFiles([
    make('supporting-information-file', {label: null, id: 1})
  ]);
  allowPermissionOnTask('edit', testTask);
  this.set('testTask', testTask);
  this.render(template);
  this.$('.supporting-information-task button.task-completed').click();

  return wait().then(() => {
    assert.equal(testTask.get('completed'), false, 'task remained incomplete');
  });
});

test("it does not allow completion when any of the files' statuses are not set to 'done'", function(assert) {
  let doneFile = make('supporting-information-file', { status: 'done' });
  let processingFile = make('supporting-information-file', { status: 'processing' });
  let testTask = createTaskWithFiles([doneFile, processingFile]);
  allowPermissionOnTask('edit', testTask);

  this.set('testTask', testTask);
  let testUrl = `/api/tasks/${testTask.id}`;
  $.mockjax({url: testUrl, type: 'PUT', status: 204, responseText: '{}'});

  this.render(template);

  this.$('.task-completed').click();
  return wait().then(() => {
    assert.equal(testTask.get('completed'), false, 'task remains uncompleted');
    assert.mockjaxRequestNotMade('/api/tasks/1', 'PUT', 'it does not save the task')
  });
});

test("it does not allow completion when any of the files' labels are not defined", function(assert) {
  let doneFile = make('supporting-information-file', { status: 'done', label: null });
  let testTask = createTaskWithFiles([doneFile]);
  allowPermissionOnTask('edit', testTask);
  this.set('testTask', testTask);
  let testUrl = `/api/tasks/${testTask.id}`;
  $.mockjax({url: testUrl, type: 'PUT', status: 204, responseText: '{}'});

  this.render(template);

  this.$('.task-completed').click();
  return wait().then(() => {
    assert.equal(testTask.get('completed'), false, 'task remains uncompleted');
    assert.mockjaxRequestNotMade('/api/tasks/1', 'PUT', 'it does not save the task')
  });
});

test("it does not allow completion when any of the files' categories is not defined", function(assert) {
  let doneFile = make('supporting-information-file', { status: 'done', category: null });
  let testTask = createTaskWithFiles([doneFile]);
  allowPermissionOnTask('edit', testTask);

  this.set('testTask', testTask);
  let testUrl = `/api/tasks/${testTask.id}`;
  $.mockjax({url: testUrl, type: 'PUT', status: 204, responseText: '{}'});

  this.render(template);

  this.$('.task-completed').click();
  return wait().then(() => {
    assert.equal(testTask.get('completed'), false, 'task remains uncompleted');
    assert.mockjaxRequestNotMade('/api/tasks/1', 'PUT', 'it does not save the task')
  });
});

test('the file save button turns red on task completion without save', function(assert) {
  let doneFile = make('supporting-information-file', { status: 'done', category: null });
  let testTask = createTaskWithFiles([doneFile]);
  allowPermissionOnTask('edit', testTask);

  this.set('testTask', testTask);
  let testUrl = `/api/tasks/${testTask.id}`;
  $.mockjax({url: testUrl, type: 'PUT', status: 204, responseText: '{}'});

  this.render(template);

  this.$('.si-file-edit-icon').click();
  return wait().then(() => {
    assert.elementNotFound('.si-file-save-edit-button.button--red', 'save button is not red');

    this.$('.task-completed').click();
    return wait().then(() => {
      assert.elementFound('.si-file-save-edit-button.button--red', 'save button is now red');
    });
  });
});

test('it lets you uncomplete the task when it has validation errors', function(assert) {
  let testTask = createTaskWithFiles([
    make('supporting-information-file', {category: null, id: 1})
  ]);
  this.set('testTask', testTask);
  allowPermissionOnTask('edit', testTask);

  Ember.run(() => {
    testTask.set('completed', true);
  });

  $.mockjax({url: '/api/tasks/1', type: 'PUT', status: 204, responseText: '{}'});
  this.render(template);

  assert.equal(testTask.get('completed'), true, 'task was initially completed');
  this.$('.supporting-information-task button.task-completed').click();

  return wait().then(() => {
    assert.equal(testTask.get('completed'), false, 'task was marked as incomplete');
    assert.mockjaxRequestMade('/api/tasks/1', 'PUT');
    $.mockjax.clear();

    // make sure we cannot mark it as complete, to ensure it truly was invalid
    this.$('.supporting-information-task button.task-completed').click();
    wait().then(() => {
      assert.mockjaxRequestNotMade('/api/tasks/1', 'PUT');
      assert.textPresent('.supporting-information-task', 'Please fix all errors');
      assert.equal(testTask.get('completed'), false, 'task did not change completion status');
    });
  });
});

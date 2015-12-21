import Ember from 'ember';
import { test, moduleFor } from 'ember-qunit';

moduleFor('controller:task', 'SendToApexController', {
  needs: ['controller:application'],

  beforeEach: function() {
    this.paper = Ember.Object.create({
      editable: true
    });

    this.currentUser = Ember.Object.create({
      siteAdmin: false
    });

    this.task = Ember.Object.create({
      isSubmissionTask: true,
      paper: this.paper
    });

    Ember.run(()=> {
      this.subject().set('model', this.task);
      this.subject().set('currentUser', this.currentUser);
    });
  }
});

test('#isEditable: true when the task is not a metadata task', function(assert) {
  Ember.run(()=> {
    this.task.set('isSubmissionTask', false);
    assert.equal(this.subject().get('isEditable'), true);
  });
});

test('#isEditable: always true when the user is an admin', function(assert) {
  Ember.run(()=> {
    this.currentUser.set('siteAdmin', true);
    this.task.set('isSubmissionTask', true);
    this.paper.set('editable', false);
    assert.equal(this.subject().get('isEditable'), true, 'task is editable');
  });
});

test('#isEditable: true when paper is editable and task is a metadata task', function(assert) {
  Ember.run(()=> {
    this.paper.set('editable', true);
    assert.equal(this.subject().get('isEditable'), true);
  });
});

test('#isEditable: false when the paper is not editable and the task is a metadata task', function(assert) {
  Ember.run(()=> {
    this.paper.set('editable', false);
    this.task.set('isSubmissionTask', true);
    assert.equal(this.subject().get('isEditable'), false);
  });
});

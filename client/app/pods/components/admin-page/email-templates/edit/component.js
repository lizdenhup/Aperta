import Ember from 'ember';
import dirtyEditor from 'tahi/mixins/components/dirty-editor';

// This validation works for our pre-populated letter templates
// but we might want to change this up when users are allowed to create
// new templates.

export default Ember.Component.extend(dirtyEditor, {
  dirtyEditorConfig: {
    model: 'template',
    properties: ['body', 'subject']
  },
  showDirtyOverlay: false,
  store: Ember.inject.service(),
  routing: Ember.inject.service('-routing'),
  disabled: Ember.computed('template.subject', 'template.body', function() {
    return !this.get('template.subject') || !this.get('template.body');
  }),
  unsaved: true,
  allowStoppedTransition: 'allowStoppedTransition',

  actions: {
    save: function() {
      if (this.get('disabled') || this.get('template.isSaving')) {
        this.set('unsaved', false);
      } else {
        this.get('template').save().then(() => {
          this.get('routing').transitionTo('admin.journals.emailtemplates', this.get('template.journal.id'));
        });
      }
    },
    cleanEmailTemplate: function() {
      let emailTemplate = this.get('template');
      if (emailTemplate.get('hasDirtyAttributes')) {
        emailTemplate.rollbackAttributes();
      }
      this.sendAction('allowStoppedTransition');
    }
  }
});

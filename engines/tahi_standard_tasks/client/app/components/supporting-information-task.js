import TaskComponent from 'tahi/pods/components/task-base/component';
import FileUploadMixin from 'tahi/mixins/file-upload';
import ObjectProxyWithErrors from 'tahi/models/object-proxy-with-validation-errors';
import Ember from 'ember';

const { computed } = Ember;

export default TaskComponent.extend(FileUploadMixin, {
  uploadCount: null, // defined by component
  classNames: ['supporting-information-task'],
  files: computed.alias('task.paper.supportingInformationFiles'),
  uploadUrl: computed('task', function() {
    return `/api/supporting_information_files?task_id=${this.get('task.id')}`;
  }),

  saveErrorText: 'Please edit and complete the required fields.',

  validateData() {
    const objs = this.get('filesWithErrors');
    objs.invoke('validateAll');

    let errors = ObjectProxyWithErrors.errorsPresentInCollection(objs); // returns a boolean
    if (this.get('uploadCount')) {
      errors = true;
    }

    if(errors) {
      this.set(
        'validationErrors.completed',
        this.get('completedErrorText')
      );
    }
  },

  filesWithErrors: computed('files.[]', function() {
    let proxies = this.get('files').map((f)=> {
      return this.get('cachedFilesWithErrors').findBy('object', f) || this.makeFileWithErrors(f);
    });
    this.set('cachedFilesWithErrors', proxies);
    return proxies;
  }),
  cachedFilesWithErrors: [],
  makeFileWithErrors(f){
    return ObjectProxyWithErrors.create({
      saveErrorText: this.get('saveErrorText'),
      object: f,
      skipValidations: () => { return this.get('skipValidations'); },
      validations: {
        processed: [{
          type: 'processingFinished',
          message: 'All files must be done processing to save.',
          validation() {
            const file = this.get('object');
            return file.get('status') === 'done';
          }
        }],
        'label': ['presence'],
        'category': ['presence']
      }
    });
  },

  actions: {
    uploadStarted(data, filename) {
      if (this.get('uploadCount')) {
        this.set('uploadCount', this.get('uploadCount') + 1);
      } else {
        this.set('uploadCount', 1);
      }
      this.uploadStarted(data, filename);
    },

    uploadFinished(data, filename) {
      this.set('uploadCount', this.get('uploadCount') - 1);
      const id = data.supporting_information_file.id;
      this.uploadFinished(data, filename);
      this.get('store').pushPayload('supporting-information-file', data);

      const siFile = this.get('store').peekRecord('supporting-information-file', id);
      const proxyObject = this.get('filesWithErrors').findBy('object', siFile);
      proxyObject.set('newlyUploaded', true);
    },

    deleteFile(file) {
      file.destroyRecord();
    },

    updateFile(file) {
      this.clearAllValidationErrorsForModel(file);
      file.save();
    }
  }
});

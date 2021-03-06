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
import ValidationErrorsMixin from 'tahi/mixins/validation-errors';
import { formatDate, formatFor, moment } from 'tahi/lib/aperta-moment';

export default Ember.Component.extend(ValidationErrorsMixin, {
  close: null,
  restless: Ember.inject.service(),
  store: Ember.inject.service(),
  attachments: Ember.computed.reads('model.attachments'),

  timeSent: Ember.computed('model.sentAt', function() {
    let sentAt = this.get('model.sentAt');
    let time = Ember.isBlank(sentAt) ? moment.utc() : moment.utc(sentAt);
    return formatDate(time, 'hour-minute-2');
  }),

  dateSent: Ember.computed('model', function() {
    let sentAt = this.get('model.sentAt');
    let date = Ember.isBlank(sentAt) ? moment.utc() : moment.utc(sentAt);
    return formatDate(date, 'month-day-year');
  }),

  prepareModelDate() {
    let date = this.get('dateSent');
    let time = this.get('timeSent');
    let m = moment.utc(date + ' ' + time, formatFor('month-day-year-time'));
    this.get('model').set('date', m.local().toJSON());
  },

  validateDate() {
    let dateIsValid = moment(this.get('dateSent'), formatFor('month-day-year')).isValid();

    if (!dateIsValid) {
      this.set('validationErrors.dateSent', 'Invalid Date.');
    }

    return dateIsValid;
  },

  validateTime() {
    let timeIsValid = moment(this.get('timeSent'), formatFor('hour-minute-1')).isValid();

    if (!timeIsValid) {
      this.set('validationErrors.timeSent', 'Invalid Time.');
    }

    return timeIsValid;
  },

  validateMandatoryPresence() {
    // This mimics the presence validations on the client side.
    let isValid = true;
    let mandatoryFields = ['description', 'sender', 'recipients', 'body'];
    for (let i = 0; i < mandatoryFields.length; i++) {
      let mandatoryFieldValue = this.get('model.' + mandatoryFields[i]);
      if (mandatoryFieldValue === '' ||
          mandatoryFieldValue === null ||
          mandatoryFieldValue === undefined) {
        this.set('validationErrors.' + mandatoryFields[i], 'This field is required.');
        isValid = false;
      }
    }
    return isValid;
  },

  validateFields() {
    let dateIsValid = this.validateDate();
    let timeIsValid = this.validateTime();
    let mandatoryPresence = this.validateMandatoryPresence();
    return dateIsValid &&
           timeIsValid &&
           mandatoryPresence;
  },

  actions: {
    saveContentsBody(contents) {
      this.set('model.body', contents);
    },

    updateAttachment(s3Url, file, attachment) {
      attachment.set('src', s3Url);
      attachment.set('filename', file.name);
      attachment.set('title', file.name);
      if (Ember.isPresent(attachment.get('id'))) {
        attachment.save();
      }
    },

    createAttachment(s3Url, file) {
      let attachment = this.get('store').createRecord('correspondence-attachment', {
        src: s3Url,
        filename: file.name
      });
      this.get('attachments').pushObject(attachment);
    },

    submit(model) {
      if (this.get('isUploading')) return;

      // Client-side validations
      this.clearAllValidationErrors();
      if (!this.validateFields()) return;

      // The way Correspondence was originally serialized makes this necessary
      this.prepareModelDate();

      // Setup the association late because, any earlier and this model would
      // be added to the correspondence list as it is being created.
      // 7 Nov, 2017  This component is now being reused for editing correspondence
      // thus it is necessary to check that the paper relationship doesn't exist already
      // before setting it.
      if (Ember.isEmpty(model.get('paper'))) {
        model.set('paper', this.get('paper'));
      }

      model.save().then(() => {
        this.clearAllValidationErrors();
        let attachments = this.get('attachments').filterBy('id', null);
        attachments.forEach(attachment => {
          attachment.save();
        });

        this.sendAction('close');
      }, (failure) => {
        // Break the association to remove this from the index.
        model.set('paper', this.get('paper'));
        this.displayValidationErrorsFromResponse(failure);
      });
    }
  }
});

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
import { filteredUsersPath } from 'tahi/utils/api-path-helpers';
import { task, timeout } from 'ember-concurrency';
import { mousedown as powerSelectFocus } from 'tahi/lib/power-select-event-trigger';
import { PropTypes } from 'ember-prop-types';

const {
  Component,
  computed,
  inject: {service},
  isPresent,
  run: {later, schedule}
} = Ember;

export default Component.extend({
  propTypes: {
    canManage: PropTypes.bool,
    canRemoveSingleUser: PropTypes.bool,
    currentParticipants: PropTypes.arrayOf(PropTypes.EmberObject).isRequired,
    displayEmails: PropTypes.bool,
    label: PropTypes.string,
    searching: PropTypes.bool,
    dropdownClass: PropTypes.string,
    // ember-power-select property
    afterOptionsComponent: PropTypes.string,

    // url OR paperId is required
    url: PropTypes.string,
    paperId: PropTypes.oneOfType([
      PropTypes.string,
      PropTypes.number
    ]),

    // actions:
    onRemove: PropTypes.func.isRequired,
    onSelect: PropTypes.func.isRequired,
    searchStarted: PropTypes.func.isRequired,
    searchFinished: PropTypes.func.isRequired
  },

  getDefaultProps() {
    return {
      currentParticipants: null,
      // display email of user in tooltip
      displayEmails: false,
      // used to toggle display of add button and search user field
      searching: false
    };
  },

  dropdownClass: 'aperta-select',
  classNames: ['participant-selector'],
  ajax: service(),

  participantUrl: computed('paperId', 'url', function() {
    return isPresent(this.get('url')) ?
      this.get('url') :
      filteredUsersPath(this.get('paperId'));
  }),

  canRemove: computed('canManage', 'canRemoveSingleUser', 'currentParticipants.[]', function() {
    if (this.get('canRemoveSingleUser')) {
      return this.get('canManage') && this.get('currentParticipants').length === 1;
    } else {
      return this.get('canManage') && this.get('currentParticipants').length > 1;
    }
  }),

  searchUsersTask: task(function* (term) {
    if(!Ember.testing) {
      yield timeout(250);
    }
    const { users } = yield this.get('ajax').request(this.get('participantUrl') + '?query=' + window.encodeURIComponent(term));
    const participantIds = this.get('currentParticipants').mapBy('id').map((num) => parseInt(num));
    return users.reject((user) => participantIds.includes(parseInt(user.id)));
  }),

  actions: {
    toggleSearching(newState) {
      if(newState) {
        this.get('searchStarted')(newState);
        schedule('afterRender', this, function() {
          powerSelectFocus(this.$('.ember-power-select-trigger'));
        });
        return;
      }

      // Give power-select a moment to hide dropdown component
      // Without this, set on undefined object error
      later(this, function() {
        this.get('searchFinished')(newState);
      }, 50);
    },

    handleInput(value) {
      if(value.length < 3) { return false; }
    },

    addParticipant(newParticipant) {
      return this.get('onSelect')(newParticipant);
    },

    removeParticipant(participant) {
      return this.get('onRemove')(participant.id);
    }
  }
});

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
import ENV from 'tahi/config/environment';
import EmberPusher from 'ember-pusher';

const { getOwner } = Ember;

const debug = function(description, obj) {
  const devOrTest = ENV.environment === 'development' ||
                    ENV.environment === 'test' ||
                    Ember.testing;

  if(devOrTest) {
    console.groupCollapsed(description);
    console.log(Ember.copy(obj, true));
    console.groupEnd();
  }
};

export default Ember.Route.extend(EmberPusher.Bindings, {
  restless: Ember.inject.service(),
  notifications: Ember.inject.service(),
  pusher: Ember.inject.service(),
  fullStory: Ember.inject.service(),
  isLoggedIn: Ember.computed.notEmpty('currentUser'),

  beforeModel() {
    Ember.assert('Application name is required for proper display', window.appName);
    this.wirePusher();
    if (this.get('isLoggedIn')) {
      this.store.findAll('journal').then( (journals) => {
        let controller = this.controllerFor('application');
        controller.set('journals', journals);
        controller.setCanViewPaperTracker();
      });
    }
  },

  wirePusher() {
    if (this.currentUser) {
      // subscribe to user and system channels
      let pusher = this.get('pusher');
      let userChannelName = `private-user@${ this.currentUser.get('id') }`;
      pusher.wire(this, 'system', ['destroyed']);
      pusher.wire(
        this,
        userChannelName,
        ['created', 'updated', 'destroyed', 'flashMessage']
      );
    }
  },

  setupController(controller, model) {
    controller.set('model', model);
    if (this.currentUser) {
      this.get('restless').authorize(
        controller,
        '/api/admin/journals/authorization',
        'canViewAdminLinks'
      );

      this.get('fullStory').identify(this.currentUser);
    }
  },

  applicationSerializer: Ember.computed(function() {
    return getOwner(this).lookup('serializer:application');
  }),

  assignWindowLocation(location) {
    window.location.assign(location);
  },

  actions: {
    willTransition(transition) {
      let currentRouteController = this.controllerFor(
        this.controllerFor('application').get('currentRouteName')
      );

      if (currentRouteController.get('isUploading')) {
        let q = 'You are uploading. Are you sure you want abort uploading?';
        if (window.confirm(q)) {
          currentRouteController.send('cancelUploads');
        } else {
          transition.abort();
          return;
        }
      }
    },

    error(response, transition) {
      const oldState   = transition.router.oldState;
      const targetName = transition.targetName;
      const prefix     = 'Error in transition';
      let transitionMsg;

      if(oldState) {
        let lastRoute  = oldState.handlerInfos.get('lastObject.name');
        transitionMsg = `${prefix} from ${lastRoute} to ${targetName}`;
      } else {
        transitionMsg = `${prefix} into ${targetName}`;
      }

      this.logError(
        transitionMsg + '\n' + response.message + '\n' + response.stack + '\n'
      );

      transition.abort();
    },

    created(payload) {
      debug(`Pusher: created ${payload.type} ${payload.id}`);

      if(payload.type === 'notification') {
        this.send('notificationAction', 'created', payload);
        return;
      }

      this.store.findRecord(payload.type, payload.id, { reload: true });
    },

    updated(payload) {
      const record = this.store.getPolymorphic(payload.type, payload.id);
      if (record && !record.get('isDeleted')) {
        record.reload();
        debug(`Pusher: updated ${payload.type} ${payload.id}`);
      }
    },

    destroyed(payload) {
      debug(`Pusher: destroyed ${payload.type} ${payload.id}`, payload);

      if(payload.type === 'notification') {
        this.send('notificationAction', 'destroyed', payload);
        return;
      }

      const record = this.store.getPolymorphic(payload.type, payload.id);
      if(record) {
        record.unloadRecord();
      }
    },

    notificationAction(action, payload) {
      this.get('notifications')[action](payload);
    },

    flashMessage(payload) {
      this.flash.displayRouteLevelMessage(payload.messageType, payload.message);
    },

    signOut() {
      this.get('fullStory').clearSession();
      this.assignWindowLocation('/users/sign_out');
    }
  },

  _pusherEventsId() {
    // needed for the `wire` and `unwire` method
    // to think we have `ember-pusher/bindings` mixed in
    return this.toString();
  }
});

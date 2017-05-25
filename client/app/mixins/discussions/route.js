import Ember from 'ember';
import DiscussionsRoutePathsMixin from 'tahi/mixins/discussions/route-paths';

export default Ember.Mixin.create(DiscussionsRoutePathsMixin,{
  subscribedTopics: [],
  popoutRoute: 'index',
  popoutDiscussionId: null,

  model() {
    const paper = this.modelFor('paper');
    return Ember.RSVP.hash({
      atMentionableStaffUsers: paper.atMentionableStaffUsers()
    });
  },

  activate() {
    this.set('popoutRoute', 'index');
    this.set('popoutDiscussionId', null);
  },

  actions: {
    popOutDiscussions() {
      let paperId = this.modelFor('paper').id;

      let options = {
        paperId: paperId,
        discussionId: this.get('popoutDiscussionId'),
        path: 'discussions.paper.' + this.get('popoutRoute')
      };

      this.send('openDiscussionsPopout', options);
      this.send('hideDiscussions');
    },

    updatePopoutRoute(route) {
      this.set('popoutRoute', route);
    },

    updateDiscussionId(id) {
      this.set('popoutDiscussionId',id);
    },

    hideDiscussions() {
      this.transitionTo(this.get('topicsParentPath'));
    }
  }
});

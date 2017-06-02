import Ember from 'ember';
import DiscussionsShowControllerMixin from 'tahi/mixins/discussions/show/controller';

export default Ember.Controller.extend(DiscussionsShowControllerMixin, {
  // required by the mixin to generate route paths:
  makeBasePath() {
    return 'discussions.paper';
  }
});

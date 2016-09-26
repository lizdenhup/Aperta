import Ember from 'ember';

export default Ember.Component.extend({
  linkedInvitations: Ember.computed.filter('invitations.@each.primary', function(inv) {
    return inv.get('alternates.length');
  }),

  mainQueueInvitations: Ember.computed.filter('invitations.@each.primary', function(inv) {
    return !inv.get('primary') && !inv.get('alternates.length');
  })
});
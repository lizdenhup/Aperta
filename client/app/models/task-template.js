import DS from 'ember-data';
import Ember from 'ember';

export default DS.Model.extend({
  card: DS.belongsTo('card'),
  journalTaskType: DS.belongsTo('journal-task-type', { async: false }),
  phaseTemplate: DS.belongsTo('phase-template', { async: false }),
  position: DS.attr('number'),
  template: DS.attr(),
  title: DS.attr('string'),
  type: Ember.computed.readOnly('kind'),
  kind: Ember.computed.readOnly('journalTaskType.kind'),
  settings: DS.attr(),
  settingsEnabled: DS.attr()
});

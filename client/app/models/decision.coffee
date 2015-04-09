`import DS from 'ember-data'`

Decision = DS.Model.extend
  letter: DS.attr("string")
  revisionNumber: DS.attr("number")
  verdict: DS.attr("string")
  paper: DS.belongsTo("paper")
  invitations: DS.hasMany("invitation")

`export default Decision`

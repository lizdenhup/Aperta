a = DS.attr
ETahi.Task = DS.Model.extend ETahi.CardThumbnailObserver,
  assignee: DS.belongsTo('user')
  assignees: DS.hasMany('user')
  phase: DS.belongsTo('phase')
  comments: DS.hasMany('comment')
  participants: DS.hasMany('user')

  body: a()
  completed: a('boolean')
  paperTitle: a('string')
  role: a('string')
  title: a('string')
  type: a('string')
  qualifiedType: a('string')

  isMetadataTask: false
  isMessage: Ember.computed.equal('type', 'MessageTask')
  paper: DS.belongsTo('paper', async: true)
  litePaper: DS.belongsTo('litePaper')
  cardThumbnail: DS.belongsTo('cardThumbnail', inverse: 'task')

  questions: DS.hasMany('question', inverse: 'task')

  relationshipsToSerialize: ['participants']

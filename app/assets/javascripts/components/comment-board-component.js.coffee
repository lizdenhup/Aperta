ETahi.CommentBoardComponent = Ember.Component.extend
  comments: []
  commentBody: ""
  commentsToShow: 5
  showingAllComments: false

  commentSort: ['createdAt:desc']
  sortedComments: Ember.computed.sort('comments', 'commentSort')

  firstComments: ETahi.computed.limit 'sortedComments', 5

  setupFocus: (->
    @$('.new-comment').on('focus', (e) =>
      @$('.form-group').addClass('editing')
    )
  ).on('didInsertElement')

  shownComments: (->
    comments = @get('comments')
    lastIndex = comments.get('length')
    if @get('showingAllComments') then comments else comments.slice(lastIndex - @get("commentsToShow"), lastIndex)
  ).property('comments.@each.createdAt', 'showingAllComments')

  showingAllComments: (->
    @get('comments.length') <= @get('commentsToShow')
  ).property('comments.length')

  omittedCommentsCount: (->
    @get('comments.length') - @get("commentsToShow")
  ).property('comments.length')

  actions:
    showAllComments: ->
      @set('showingAllComments', true)

    postComment: ->
      @sendAction('postComment', @get("commentBody"))
      @send('clearComment')

    clearComment: ->
      @set('commentBody', "")
      @$('.form-group').removeClass('editing')

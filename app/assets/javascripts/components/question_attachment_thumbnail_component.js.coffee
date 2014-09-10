ETahi.QuestionAttachmentThumbnailComponent = Ember.Component.extend ETahi.SpinnerMixin,
  classNameBindings: ['destroyState:_destroy']
  destroyState: false
  previewState: false
  uploadingState: false

  spinnerOpts: (->
    lines: 7 # The number of lines to draw
    length: 0 # The length of each line
    width: 5 # The line thickness
    radius: 5 # The radius of the inner circle
    corners: 1 # Corner roundness (0..1)
    rotate: 0 # The rotation offset
    direction: 1 # 1: clockwise, -1: counterclockwise
    color: '#fff' # #rgb or #rrggbb or array of colors
    speed: 1.3 # Rounds per second
    trail: 68 # Afterglow percentage
    shadow: false # Whether to render a shadow
    hwaccel: false # Whether to use hardware acceleration
    className: 'spinner' # The CSS class to assign to the spinner
    zIndex: 2e9 # The z-index (defaults to 2000000000)
    top: '60%'
    left: '50%'
  ).property()

  scrollToView: ->
    $('.overlay').animate
      scrollTop: @$().offset().top + $('.overlay').scrollTop()
    , 500, 'easeInCubic'

  toggleSpinner: (->
    @createSpinner('showSpinner', '.replace-spinner', @get('spinnerOpts'))
  ).observes('showSpinner').on('didInsertElement')

  isProcessing: ( ->
    @get('attachment.status') == "processing"
  ).property('attachment.status')

  showSpinner: Ember.computed.or('isProcessing', 'uploadingState')

  actions:
    cancelDestroyAttachment: -> @set 'destroyState', false

    confirmDestroyAttachment: -> @set 'destroyState', true

    destroyAttachment: ->
      this.$().fadeOut 250, => @get('attachment').destroyRecord()

    attachmentUploading: ->
      @set('uploadingState', true)

    attachmentUploaded: (data) ->
      store = @get('attachment.store')
      store.pushPayload 'questionAttachment', data
      @set('uploadingState', false)

    togglePreview: ->
      @toggleProperty 'previewState'
      @scrollToView() if @get 'previewState'

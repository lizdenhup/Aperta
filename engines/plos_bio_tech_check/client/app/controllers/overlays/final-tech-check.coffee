`import Ember from 'ember'`
`import TaskController from 'tahi/pods/paper/task/controller'`

FinalTechCheckOverlayController = TaskController.extend
  restless: Ember.inject.service()

  authoringMode: (-> false).property()

  successText:
    "The author has been notified via email that changes are needed. They will also see
    your message the next time they log in to see their manuscript."

  buttonText: "Send Changes to Author"

  authorChangesLetter: (->
  ).property()

  setLetter: (callback) ->
    @set 'model.body', finalTechCheckBody: @get("authorChangesLetter")

    @get('model').save().then =>
      @flash.displayMessage('success', 'Author Changes Letter has been Saved')
      callback()

  actions:
    setUILetter: ->
      @set("authorChangesLetter", @get('model.body.finalTechCheckBody'))

    activateAuthoringMode: ->
      @send "setUILetter"
      @set 'authoringMode', true

    saveLetter: (@callback) ->
      @setLetter(->)

    sendEmail: ->
      @setLetter =>
        path = "/api/final_tech_check/#{@get("model.id")}/send_email"
        this.get('restless').post(path)

        @set 'authoringMode', false
        @flash.displayMessage('success', @get 'successText')

    setQuestionSelectedText: ->
      owner = this.get("model")
      text = @get("model.nestedQuestions").filter((q) ->
        !q.answerForOwner(owner).get("value") && q.get("additionalData")
        ).map((question) ->
          question.get("additionalData")
        ).join("\n\n")

      @set 'authorChangesLetter', text

`export default FinalTechCheckOverlayController`
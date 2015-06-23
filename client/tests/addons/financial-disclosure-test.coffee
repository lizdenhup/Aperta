`import Ember from 'ember'`
`import { test } from 'ember-qunit'`
`import startApp from '../helpers/start-app'`
`import { paperWithTask, addUserAsParticipant } from '../helpers/setups'`
`import setupMockServer from '../helpers/mock-server'`
`import Factory from '../helpers/factory'`
`import TestHelper from 'ember-data-factory-guy/factory-guy-test-helper';`


app = null
server = null
fakeUser = null
currentPaper = null
financialDisclosureTaskId = 94139
financialDisclosureTask = null
paperPayload = null

module 'FinancialDisclosureTask',
  teardown: ->
    server.restore()
    Ember.run(app, app.destroy)
  setup: ->
    app = startApp()
    server = setupMockServer()
    fakeUser = window.currentUserData.user
    TestHelper.handleFindAll('discussion-topic', 1)


    records = paperWithTask('FinancialDisclosureTask'
      id: financialDisclosureTaskId
      role: "author"
    )

    [currentPaper, financialDisclosureTask, journal, phase] = records

    paperPayload = Factory.createPayload('paper')

    paperPayload.addRecords(records.concat([fakeUser]))
    paperResponse = paperPayload.toJSON()
    paperResponse.participations = [addUserAsParticipant(financialDisclosureTask, fakeUser)]

    taskPayload = Factory.createPayload('task')
    taskPayload.addRecords([financialDisclosureTask, fakeUser])
    financialDisclosureTask = taskPayload.toJSON()

    collaborators = [
      id: "35"
      full_name: "Aaron Baker"
      info: "testroles2, collaborator"
    ]

    server.respondWith 'GET', "/api/papers/#{currentPaper.id}", [
      200, {"Content-Type": "application/json"}, JSON.stringify paperResponse
    ]
    server.respondWith 'GET', "/api/tasks/#{financialDisclosureTaskId}", [
      200, {"Content-Type": "application/json"}, JSON.stringify financialDisclosureTask
    ]
    server.respondWith 'PUT', /\/api\/tasks\/\d+/, [
      204, {"Content-Type": "application/json"}, JSON.stringify {}
    ]
    server.respondWith 'GET', /\/api\/filtered_users\/users\/\d+/, [
      200, {"Content-Type": "application/json"}, JSON.stringify []
    ]

    server.respondWith 'POST', '/api/questions', [
      204, {"Content-Type": "application/json"}, JSON.stringify []
    ]

    mirrorCreateResponse = (key, newId) ->
      (xhr) ->
        createdItem = JSON.parse(xhr.requestBody)
        createdItem[key].id = newId
        response = JSON.stringify createdItem
        xhr.respond(201,{"Content-Type": "application/json"}, response)

    server.respondWith 'POST', "/api/funders", mirrorCreateResponse('funder', 1)

test 'Viewing card', ->
  visit "/papers/#{currentPaper.id}/edit"
  click ':contains("Financial")'
  .then ->
    equal find('.overlay-main-work h1').text().trim(), 'Financial Disclosures'
    ok find("label:contains('Yes')").length
    click "label:contains('Yes')"
    .then ->
      ok find("button:contains('Add Another Funder')").length, "User can add another funder"
      ok find("span.remove-funder").length, "User can add remove the funder"


# test "Removing an existing funder when there's only 1", ->
# #   ef = ETahi.Factory
# #   records = ETahi.Setups.paperWithTask ('FinancialDisclosureTask')
# #   paper = records[0]
# #   task = records[1]
# #   author = ef.createAuthor(paper)
#   funder = Factory.createRecord('Funder', author_ids: 1, task_id: 94139, id: 1)
#   financialDisclosureTask.funder_ids = [1]
#   paperPayload.addRecords(records.concat([funder]))
#
#   server.respondWith 'GET', "/papers/#{currentPaper.id}", [
#     200, {"Content-Type": "application/json"}, JSON.stringify paperPayload.toJSON()
#   ]
#
#   server.respondWith 'DELETE', "/funders/1", [
#     204, {"Content-Type": "application/html"}, ""
#   ]
#
#   visit "/papers/#{currentPaper.id}"
#   click "a.remove-funder-link"
#   andThen ->
#     ok _.findWhere(server.requests, {method: "DELETE", url: "/funders/1"}), "It posts to the server to delete the funder"
#     ok find('input#received-funding-no:checked').length, "Received funding is set to 'no'"

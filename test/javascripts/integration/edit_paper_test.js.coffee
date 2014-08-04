module 'Integration: EditPaper',
  teardown: -> ETahi.reset()
  setup: ->
    setupApp(integration: true)

    paperId = 93412
    figureTaskId = 94139
    authorId = 19932347

    dashboard =
      users: [fakeUser.user]
      affiliations: []
      lite_papers: [
        id: paperId
        title: null
        paper_id: paperId
        short_title: "Paper"
        submitted: false
      ]
      card_thumbnails: [
        id: figureTaskId
        task_type: "FigureTask"
        completed: false
        task:
          id: figureTaskId
          type: "FigureTask"
        title: "Upload Figures"
        lite_paper_id: paperId
        assignee_id: fakeUser.user.id
      ]
      dashboards: [
        id: 1
        user_id: fakeUser.user.id
        submission_ids: [paperId]
        assigned_task_ids: [figureTaskId]
        administered_journals: []
      ]

    paperResponse =
      phases: [
        id: 40
        name: "Submission Data"
        position: 1
        paper_id: paperId
        tasks: [
          id: figureTaskId
          type: "FigureTask"
        ]
      ]
      tasks: [
        id: figureTaskId
        title: "Upload Figures"
        type: "StandardTasks::FigureTask"
        completed: false
        body: null
        paper_title: "Foo"
        role: "author"
        phase_id: 40
        paper_id: paperId
        lite_paper_id: paperId
        assignee_ids: []
        assignee_id: fakeUser.user.id
      ]
      lite_papers: [
        id: paperId
        title: "Foo"
        paper_id: paperId
        short_title: "Paper"
        submitted: false
      ]
      users: [fakeUser.user]
      affiliations: []
      figures: []
      author_groups: [
        id: 41
        name: "First Author"
        author_ids: [authorId]
        paper_id: paperId
      ]
      authors: [
        id: authorId
        first_name: "Fake"
        middle_initial: null
        last_name: "User"
        email: "fakeuser@example.com"
        affiliation: null
        secondary_affiliation: null
        title: null
        corresponding: false
        deceased: false
        department: null
        position: 1
        author_group_id: 41
      ]
      supporting_information_files: []
      journals: [
        id: 3
        name: "Fake Journal"
        logo_url: "/images/no-journal-image.gif"
        paper_types: ["Research"]
        task_types: [
          "FinancialDisclosure::Task"
          "PaperAdminTask"
          "PaperEditorTask"
          "StandardTasks::PaperReviewerTask"
          "StandardTasks::RegisterDecisionTask"
          "ReviewerReportTask"
          "StandardTasks::AuthorsTask"
          "StandardTasks::CompetingInterestsTask"
          "StandardTasks::DataAvailabilityTask"
          "StandardTasks::FigureTask"
          "StandardTasks::TechCheckTask"
          "SupportingInformation::Task"
          "UploadManuscript::Task"
        ]
        manuscript_css: null
      ]
      paper:
        id: paperId
        short_title: "Paper"
        title: "Foo"
        body: null
        submitted: false
        paper_type: "Research"
        status: null
        phase_ids: [40]
        figure_ids: []
        author_group_ids: [41]
        supporting_information_file_ids: []
        assignee_ids: [fakeUser.user.id]
        editor_ids: []
        reviewer_ids: []
        tasks: [
          id: figureTaskId
          type: "FigureTask"
        ]
        journal_id: 3

    figureTaskResponse =
      lite_papers: [
        id: paperId
        title: "Foo"
        paper_id: paperId
        short_title: "Paper"
        submitted: false
      ]
      users: [fakeUser.user]
      affiliations: []
      task:
        id: figureTaskId
        title: "Upload Figures"
        type: "StandardTasks::FigureTask"
        completed: false
        body: null
        paper_title: "Foo"
        role: "author"
        phase_id: 40
        paper_id: paperId
        lite_paper_id: paperId
        assignee_ids: []
        assignee_id: fakeUser.user.id

    server.respondWith 'GET', "/dashboards", [
      200, {"Content-Type": "application/json"}, JSON.stringify dashboard
    ]
    server.respondWith 'GET', "/papers/#{paperId}", [
      200, {"Content-Type": "application/json"}, JSON.stringify paperResponse
    ]
    server.respondWith 'GET', "/tasks/#{figureTaskId}", [
      200, {"Content-Type": "application/json"}, JSON.stringify figureTaskResponse
    ]

    server.respondWith 'PUT', /\/tasks\/\d+/, [
      204, {"Content-Type": "application/json"}, JSON.stringify {}
    ]

test 'visiting /edit-paper: Author completes all metadata cards', ->
  visit '/papers/93412/edit'
  .then -> ok find('a:contains("Submit")').hasClass 'button--disabled'
  .then ->
    for card in find('#paper-metadata-tasks .card-content')
      click card
      click '#task_completed'
      click '.overlay-close-button:first'
  .then -> ok !find('a:contains("Submit")').hasClass 'button--disabled'

# Copyright (c) 2018 Public Library of Science

# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.

require 'rails_helper'
require 'support/pages/dashboard_page'
require 'support/pages/overlays/send_to_apex_overlay'
require 'support/sidekiq_helper_methods'

# rubocop:disable Style/PercentLiteralDelimiters
feature 'Send to Apex task', js: true do
  include SidekiqHelperMethods

  let!(:paper) do
    FactoryGirl.create(
      :paper,
      :ready_for_export,
      :with_creator
    )
  end
  let!(:task) do
    FactoryGirl.create(
      :send_to_apex_task,
      paper: paper,
      phase: paper.phases.first
    )
  end
  let(:internal_editor) { FactoryGirl.create(:user) }
  let(:dashboard_page) { DashboardPage.new }
  let(:manuscript_page) { dashboard_page.view_submitted_paper paper }
  let!(:server) { FakeFtp::Server.new(21212, 21213) }
  let!(:apex_html_flag) { FactoryGirl.create :feature_flag, name: "KEEP_APEX_HTML", active: false }

  before do
    # Here we are checking that the URLs have similar elements to be the 'same'
    # request. If the URIs match the given patterns, we have a match and can
    # use the associated cassette.
    @start_with_matcher = lambda do |app_request, vcr_request|
      # //tahi-test.s3-us-west-1.amazonaws.com/uploads/paper/1/attachment/1/ea85b0d61253e1033eab985b8ab1097187216cd45bce749956630c5914758bb9/about_turtles.docx|
      matched = false
      if app_request.method == vcr_request.method
        matched = app_request.uri == vcr_request.uri || begin
          regexp = %r|/uploads/paper/#{paper.id}/attachment/#{paper.file.id}/#{paper.file.file_hash}/#{paper.file.filename}|
          app_request.uri =~ regexp && vcr_request.uri =~ %r|/uploads/paper/\d+/attachment/\d+/[^\/]+/#{paper.file.filename}|
        end
      end
      matched
    end
    server.start

    assign_internal_editor_role paper, internal_editor

    login_as(internal_editor, scope: :user)
    visit '/'
  end

  after do
    server.stop
  end

  scenario 'User can send a paper to Send to Apex' do
    export_delivery = TahiStandardTasks::ExportDelivery.where(paper_id: paper.id)
    expect(export_delivery.count).to be 0

    overlay = Page.view_task_overlay(paper, task)
    overlay.click_button('Send to Apex')
    overlay.ensure_apex_upload_is_pending
    VCR.use_cassette(
      'send_to_apex',
      allow_playback_repeats: true,
      match_requests_on: [:method, @start_with_matcher],
      record: :new_episodes
    ) do
      process_sidekiq_jobs
      expect(server.files).to include(paper.manuscript_id + '.zip')
    end

    overlay.ensure_apex_upload_has_succeeded
  end
end
# rubocop:enable Style/PercentLiteralDelimiters

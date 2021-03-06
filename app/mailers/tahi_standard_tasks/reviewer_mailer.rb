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

module TahiStandardTasks
  class ReviewerMailer < ApplicationMailer
    include Rails.application.routes.url_helpers
    include MailerHelper
    include ::EmailFromLiquidTemplate
    add_template_helper ClientRouteHelper
    add_template_helper TemplateHelper
    layout "mailer"

    default from: Rails.configuration.from_email

    def notify_invited(invitation_id:)
      @invitation = Invitation.find(invitation_id)
      @invitee = @invitation.invitee
      @paper = @invitation.paper
      @task = @invitation.task
      @invitation.attachments.each do |attachment|
        attachments[attachment.filename] = attachment.file.read
      end
      @subject = "You have been invited as a reviewer " \
        "for the manuscript, \"#{@paper.display_title}\""
      mail(
        to:      @invitation.email,
        subject: @subject,
      )
    end

    def reviewer_accepted(invitation_id:)
      @invitation = Invitation.find_by(id: invitation_id)
      return if @invitation.blank? || @invitation.inviter.blank?

      @invite_reviewer_task = @invitation.task
      @paper = @invite_reviewer_task.paper
      @journal = @paper.journal

      send_mail_from_letter_template(
        journal: @journal,
        letter_ident: 'reviewer-accepted',
        scenario: InvitationScenario.new(@invitation),
        check_blanks: false
      )
    end

    def reviewer_declined(invitation_id:)
      @invitation = Invitation.find_by(id: invitation_id)
      return if @invitation.blank? || @invitation.inviter.blank?

      @invite_reviewer_task = @invitation.task
      @paper = @invite_reviewer_task.paper
      @journal = @paper.journal

      send_mail_from_letter_template(
        journal: @journal,
        letter_ident: 'reviewer-declined',
        scenario: InvitationScenario.new(@invitation),
        check_blanks: false
      )
    end

    def welcome_reviewer(assignee_id:, paper_id:)
      @paper = Paper.find(paper_id)
      @reviewer_report = ReviewerReport.where( user_id: assignee_id, decision: @paper.draft_decision).first
      @journal = @paper.journal
      @invitation = @reviewer_report.invitation

      send_mail_from_letter_template(
        journal: @journal,
        letter_ident: 'reviewer-welcome',
        scenario: ReviewerReportScenario.new(@reviewer_report),
        check_blanks: false
      )
    end

    def remind_before_due(reviewer_report_id:)
      reminder_notice(letter_template_ident: 'review-reminder-before-due', reviewer_report_id: reviewer_report_id)
    end

    def first_late_notice(reviewer_report_id:)
      reminder_notice(letter_template_ident: 'review-reminder-first-late', reviewer_report_id: reviewer_report_id)
    end

    def second_late_notice(reviewer_report_id:)
      reminder_notice(letter_template_ident: 'review-reminder-second-late', reviewer_report_id: reviewer_report_id)
    end

    def thank_reviewer(reviewer_report_id:)
      @reviewer_report = ReviewerReport.find(reviewer_report_id)
      @paper = @reviewer_report.paper
      @journal = @paper.journal
      @letter_template = @journal.letter_templates.find_by(ident: 'reviewer-appreciation')
      begin
        @letter_template.render(ReviewerReportScenario.new(@reviewer_report), check_blanks: true)
        @subject = @letter_template.subject
        @body = @letter_template.body
        @to = @reviewer_report.user.email
        @cc = @letter_template.cc
        @bcc = @letter_template.bcc
        mail(to: @to, cc: @cc, bcc: @bcc, subject: @subject)
      rescue BlankRenderFieldsError => e
        Bugsnag.notify(e)
      end
    end

    private

    def reminder_notice(letter_template_ident:, reviewer_report_id:)
      @reviewer_report = ReviewerReport.find(reviewer_report_id)
      @paper = @reviewer_report.paper
      @journal = @paper.journal
      @letter_template = @journal.letter_templates.find_by(ident: letter_template_ident)
      @invitation = @reviewer_report.invitation
      begin
        @letter_template.render(ReviewerReportScenario.new(@reviewer_report), check_blanks: true)
        @subject = @letter_template.subject
        @body = @letter_template.body
        @to = @reviewer_report.user.email
        @cc = @letter_template.cc
        @bcc = @letter_template.bcc
        mail(to: @to, cc: @cc, bcc: @bcc, subject: @subject, template_name: 'review_due_reminder')
      rescue BlankRenderFieldsError => e
        Bugsnag.notify(e)
      end
    end
  end
end

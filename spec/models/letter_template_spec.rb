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

describe LetterTemplate do
  describe 'update validations' do
    [:body, :subject].each do |attr_key|
      it "requires a #{attr_key}" do
        letter_template = LetterTemplate.new(id: 1)
        letter_template.valid?
        expect(letter_template).to_not be_valid
        expect(letter_template.errors[attr_key]).to include("can't be blank")
      end
    end

    it 'has valid liquid syntax in subject' do
      letter_template =
        FactoryGirl.build(:letter_template,
                           subject: "{{ subject }")
      expect(letter_template).to_not be_valid
      expect(letter_template.errors[:subject])
        .to include("Variable '{{ subject }' was not properly terminated with regexp: /\\}\\}/")
    end

    it 'has valid liquid syntax in body' do
      letter_template =
        FactoryGirl.build(:letter_template,
                           body: "Interesting text about {{ subject }} from {{ email }")
      expect(letter_template).to_not be_valid
      expect(letter_template.errors[:body])
        .to include("Variable '{{ email }' was not properly terminated with regexp: /\\}\\}/")
    end
  end

  describe 'new template validations' do
    it 'requires a name and a scenario on first create' do
      letter_template = LetterTemplate.new(name: 'Test', scenario: 'Reviewer Report')
      letter_template.valid?
      expect(letter_template).to_not be_valid

      [:name, :scenario].each do |attr_key|
        letter_template[attr_key] = nil
        letter_template.valid?
        expect(letter_template.errors[attr_key]).to include('This field is required')
      end
    end

    it 'simplifies addresses containing leading friendly names' do
      letter_template = LetterTemplate.new(cc: '"John Q. Public, the third" <jqp@example.com>, John Smith <smith@example.com>')
      letter_template.valid?
      expect(letter_template.cc).to eq('jqp@example.com,smith@example.com')
    end

    it 'disallows invalid email addresses' do
      letter_template = LetterTemplate.new(bcc: 'invalid@c.')
      letter_template.valid?
      expect(letter_template.errors[:bcc]).to include("\"#{letter_template.bcc}\" is an invalid email address")
    end
  end

  describe "#render" do
    let(:letter_template) do
      FactoryGirl.create(:letter_template,
                         subject: "{{ subject }}",
                         to: "{{ email }}",
                         body: "Interesting text about {{ subject }} from {{ email }}")
    end

    let(:letter_context) do
      {
        subject: "My subject",
        email: "plos@aperta.tech"
      }
    end

    it "sets a subject" do
      expect(letter_template.render(letter_context.stringify_keys).subject).to eq(letter_context[:subject])
    end

    it "sets the to field" do
      expect(letter_template.render(letter_context.stringify_keys).to).to eq(letter_context[:email])
    end

    it "sets the body" do
      expected_body = "Interesting text about #{letter_context[:subject]} from #{letter_context[:email]}"
      expect(letter_template.render(letter_context.stringify_keys).body).to eq(expected_body)
    end

    context "html sanitization" do
      let(:html_letter_context) do
        {
          subject: "<p>Some html</p>",
          email: "<b>myemail@example.com</b>"
        }
      end

      it "sanitizes the subject" do
        expect(letter_template.render(html_letter_context.stringify_keys).subject).to eq("Some html")
      end

      it "sanitizes the to field" do
        expect(letter_template.render(html_letter_context.stringify_keys).to).to eq("myemail@example.com")
      end
    end

    context "with missing data" do
      let(:letter_template) do
        FactoryGirl.create(:letter_template,
                           body: "Interesting text about {{ subject }} from {{ email }}")
      end
      let(:letter_context) do
        {
          subject: "",
          email: ""
        }
      end

      it 'adds blank fields to error object' do
        expect { letter_template.render(letter_context.stringify_keys, check_blanks: true) }.to raise_error BlankRenderFieldsError, '["subject", "email"]'
      end
    end
  end

  describe "letter template seed" do
    before :all do
      Rake::Task.define_task(:environment)
    end

    before :each do
      FactoryGirl.create(:journal)
      Rake::Task['seed:letter_templates:populate'].reenable
      Rake.application.invoke_task 'seed:letter_templates:populate'
      Rake::Task['seed:letter_templates:populate'].reenable
    end

    it "doesn't reset a changed name" do
      letter_template = LetterTemplate.first
      letter_template.update(name: 'spec')
      Rake.application.invoke_task 'seed:letter_templates:populate'
      letter_template.reload
      expect(letter_template.name).to eq('spec')
    end

    it "reset ident if it was nil and template name is known" do
      letter_template = LetterTemplate.first
      orig_ident = letter_template.ident
      letter_template.update!(ident: nil)
      expect(LetterTemplate.where(ident: orig_ident)).not_to exist
      Rake.application.invoke_task 'seed:letter_templates:populate'
      expect(LetterTemplate.where(ident: orig_ident)).to exist
    end
  end

  describe '#render_dummy_data' do
    it 'loads dummy data file and render it into a template' do
      letter_template = LetterTemplate.new(body: '{{journal.name}}')
      letter_template.render_dummy_data
      expect(letter_template.body). to eq('PLOS')
    end
  end
end
# rubocop:enable Metrics/BlockLength

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

describe Behavior do
  let(:args) { { event_name: :fake_event } }
  let(:journal) { create(:journal) }

  before(:each) do
    Event.register(:fake_event)
  end

  after(:each) do
    Event.deregister(:fake_event)
  end

  describe TestBehavior do
    it_behaves_like :behavior_subclass

    context 'event validation' do
      context 'when no subject is provided' do
        subject { described_class.new }

        it 'should fail validation' do
          expect(subject).not_to be_valid
          expect(subject.errors[:event_name]).to include("can't be blank")
        end
      end

      context 'when the event_name is not registered' do
        subject { described_class.new(event_name: :fake_event_2) }

        it 'should fail validation' do
          expect(subject).not_to be_valid
          expect(subject.errors[:event_name]).to include("is not included in the list")
        end
      end

      context 'when the event_name is registered' do
        subject(:behavior) { described_class.new(event_name: :fake_event_2) }

        it 'should be valid' do
          Event.register(:fake_event_2)
          expect(subject).to be_valid
          Event.deregister(:fake_event_2)
        end
      end
    end

    it 'should allow a bool_attr' do
      expect(described_class.new(bool_attr: true, **args)).to be_valid
    end

    context 'with a validation' do
      subject do
        Class.new(described_class) do
          def self.name
            'Test2Behavior'
          end
          has_attributes string: %w[string_attr]
          validates :string_attr, inclusion: { in: %w[foo bar] }
        end
      end

      it 'should validate string_attr' do
        expect(subject.new(string_attr: 'baz', **args)).not_to be_valid
        expect(subject.new(string_attr: 'bar', **args)).to be_valid
      end
    end
  end
end

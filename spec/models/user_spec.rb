require 'spec_helper'

describe User do
  describe "scopes" do
    let! :user1 do
      User.create! username: 'admin',
        first_name: 'Admin',
        last_name: 'Istrator',
        email: 'admin@example.org',
        password: 'password',
        password_confirmation: 'password',
        affiliation: 'PLOS'
    end

    let! :user2 do
      User.create! username: 'user',
        first_name: 'Us',
        last_name: 'Er',
        email: 'user@example.org',
        password: 'password',
        password_confirmation: 'password',
        affiliation: 'Research Institute'
    end

    describe ".admins" do
      it "includes admin users only" do
        user1.update! admin: true
        admins = User.admins
        expect(admins).to include user1
        expect(admins).not_to include user2
      end
    end

    describe ".editors_for" do
      it "includes editors for the given journal" do
        journal = Journal.create!
        JournalRole.create! journal: journal, user: user2, editor: true
        editors = User.editors_for journal
        expect(editors).to include user2
        expect(editors).to_not include user1
      end
    end
  end

  describe "#full_name" do
    it "returns the user's first and last name" do
      user = User.new first_name: 'Mihaly', last_name: 'Csikszentmihalyi'
      expect(user.full_name).to eq 'Mihaly Csikszentmihalyi'
    end
  end
end

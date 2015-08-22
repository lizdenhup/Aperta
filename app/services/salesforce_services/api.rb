module SalesforceServices
  class API
    include ObjectTranslations

    def self.get_client
      client = Databasedotcom::Client.new(
        host: Rails.configuration.salesforce_host,
        client_id: Rails.configuration.salesforce_client_id,
        client_secret: Rails.configuration.salesforce_client_secret
      )

      client.authenticate username: Rails.configuration.salesforce_username,
                          password: Rails.configuration.salesforce_password

      client
    end

    def self.client
      @@client ||= self.get_client
    end

    def self.create_manuscript(paper_id:)
      paper = Paper.find(paper_id)

      mt = ManuscriptTranslator.new(user_id: client.user_id, paper: paper)
      manuscript = self.client.materialize("Manuscript__c")
      sf_paper = manuscript.create(mt.paper_to_manuscript_hash)

      paper.update_attribute(:salesforce_manuscript_id, sf_paper.Id)
      sf_paper
    end

    def self.update_manuscript(paper_id:)
      paper = Paper.find(paper_id)

      mt = ManuscriptTranslator.new(user_id: client.user_id, paper: paper)
      manuscript = self.client.materialize("Manuscript__c")
      sf_paper = manuscript.find(paper.salesforce_manuscript_id)
      sf_paper.update_attributes mt.paper_to_manuscript_hash
      sf_paper
    end

    def self.find_or_create_manuscript(paper_id:)
      p = Paper.find(paper_id)
      if p.salesforce_manuscript_id
        self.update_manuscript(paper_id: paper_id)
      else
        self.create_manuscript(paper_id: paper_id)
      end
    end

  end
end

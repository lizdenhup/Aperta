require File.expand_path('../boot', __FILE__)

require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "sprockets/railtie"

Bundler.require(:default, Rails.env)

module Tahi
  def self.service_log
    @@service_log ||= Logger.new(STDOUT)
  end

  def self.service_log=(log)
    @@service_log = log
  end

  class Application < Rails::Application
    config.eager_load = true

    # use bin/rake tahi_standard_tasks:install:migrations
    # see http://guides.rubyonrails.org/engines.html#engine-setup
    # config.paths['db/migrate'].push 'engines/tahi_standard_tasks/db/migrate'

    config.autoload_paths += %W(#{config.root}/lib)
    config.autoload_paths += %W(#{config.root}/app/workers)

    config.s3_bucket = ENV.fetch('S3_BUCKET', :not_set)
    config.carrierwave_storage = :fog
    config.action_mailer.default_url_options = { host: ENV.fetch('DEFAULT_MAILER_URL', 'tahi.example.com') }
    config.admin_email = ENV.fetch('ADMIN_EMAIL', 'admin@example.com')
    config.from_email = ENV.fetch('FROM_EMAIL', 'no-reply@example.com')

    # Raise an error within after_rollback & after_commit
    config.active_record.raise_in_transactional_callbacks = true

    config.active_job.queue_adapter = :sidekiq

    config.basic_auth_required = ENV.fetch("BASIC_AUTH_REQUIRED", false)
    if config.basic_auth_required
      config.basic_auth_user = ENV.fetch('BASIC_HTTP_USERNAME')
      config.basic_auth_password = ENV.fetch('BASIC_HTTP_PASSWORD')
    end

    config.omniauth_providers = []
  end
end

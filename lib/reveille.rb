module Reveille
  autoload :Config,  'reveille/config'
  autoload :Event,   'reveille/event'
  autoload :Sidekiq, 'reveille/sidekiq'

  class << self
    def handlers
      Event.handlers
    end

    def jobs
      Event.jobs
    end

    def hooks
      Event.hooks
    end

    def events
      Event.events
    end
  end
  
end

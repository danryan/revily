module Revily
  module Event
    class Job
      class IncidentAcknowledgeTimeout < Job

        def process
          incident.trigger unless (incident.triggered? || incident.resolved?)
        end

        private

        def incident
          source
        end

        def source
          @source ||= Incident.find_by(uuid: payload["source"]["id"])
        end

      end
    end
  end
end

require 'hubspot/utils'

module Hubspot
  #
  # HubSpot Events HTTP API
  #
  # {https://developers.hubspot.com/docs/methods/enterprise_events/http_api}
  #
  class Event
    POST_EVENT_PATH = '/v1/event'

    class << self
      def complete(event_id, email)
        params = { _n: event_id, _a: Hubspot::Config.portal_id, email: email }
        Hubspot::EventConnection.complete(POST_EVENT_PATH, params: params).success?
      end
    end
  end
end

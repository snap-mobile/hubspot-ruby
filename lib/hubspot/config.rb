require 'logger'

module Hubspot
  class Config

    CONFIG_KEYS = [:hapikey, :base_url, :portal_id, :access_token, :logger]
    DEFAULT_LOGGER = Logger.new(nil)

    class << self
      attr_accessor *CONFIG_KEYS

      def configure(config)
        config.stringify_keys!
        @hapikey = config["hapikey"]
        @base_url = config["base_url"] || "https://api.hubapi.com"
        @portal_id = config["portal_id"]
        @access_token = config['access_token']
        @logger = config['logger'] || DEFAULT_LOGGER
        self
      end

      def reset!
        @hapikey = nil
        @base_url = "https://api.hubapi.com"
        @portal_id = nil
        @access_token = nil
        @logger = DEFAULT_LOGGER
      end

      def ensure!(*params)
        params.each do |p|
          raise Hubspot::ConfigurationError.new("'#{p}' not configured") unless instance_variable_get "@#{p}"
        end
      end
    end

    reset!
  end
end

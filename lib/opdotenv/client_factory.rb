module Opdotenv
  class ClientFactory
    # Creates appropriate client based on configuration or environment
    # Supports both op CLI and Connect API
    def self.create(env: ENV)
      # Check for Connect API configuration
      connect_url = env["OP_CONNECT_URL"] || env["OPDOTENV_CONNECT_URL"]
      connect_token = env["OP_CONNECT_TOKEN"] || env["OPDOTENV_CONNECT_TOKEN"]

      if connect_url && connect_token
        ConnectApiClient.new(base_url: connect_url, access_token: connect_token, env: env)
      else
        OpClient.new(env: env)
      end
    end
  end
end

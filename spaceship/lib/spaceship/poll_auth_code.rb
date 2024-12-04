require 'net/http'
require 'uri'
require 'json'

def retrieve_verification_code(phoneNumber, options = {})
  puts "Polling code"
  # Default options
  max_retries    = options.fetch(:max_retries, 40)
  retry_interval = options.fetch(:retry_interval, 2)  # seconds
  base_url       = options.fetch(:base_url, ENV["_BASE_URL_"])
  auth_token     = options[:auth_token]               # Optional authentication token

  uri = URI.parse("#{base_url}/api/webhook/appleAuthCode?number=#{phoneNumber}")

  (1..max_retries).each do |attempt|
    begin
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl     = (uri.scheme == 'https')
      http.open_timeout = 5
      http.read_timeout = 5

      request = Net::HTTP::Get.new(uri.request_uri)
      # Add authentication header if provided
      request['API_KEY'] = 'API_KEY'

      response = http.request(request)

      if response.is_a?(Net::HTTPSuccess)
        body = JSON.parse(response.body)
        code = body['code']
        puts "Verification code received: #{code}"
        return code  # Return the code if successful
      else
        puts "Attempt #{attempt}: Code not available yet (Status: #{response.code}). Retrying in #{retry_interval} seconds..."
        sleep retry_interval
      end
    rescue => e
      puts "Attempt #{attempt}: Error occurred - #{e.message}. Retrying in #{retry_interval} seconds..."
      sleep retry_interval
    end
  end

  # If the code wasn't retrieved after all retries
  puts "Failed to retrieve the verification code after #{max_retries} attempts."
  return ''  # Return nil to indicate failure
end
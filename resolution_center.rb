$LOAD_PATH.unshift(File.expand_path('fastlane/lib', __dir__))
$LOAD_PATH.unshift(File.expand_path('fastlane_core/lib', __dir__))
$LOAD_PATH.unshift(File.expand_path('spaceship/lib', __dir__))
$LOAD_PATH.unshift(File.expand_path('credentials_manager/lib', __dir__))

require_relative 'spaceship/lib/spaceship'
require 'zip'
require 'net/http'
require 'uri'
require 'stringio'
require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: example_named_args.rb [options]"

  opts.on("-nNUMBER", "--number=NUMBER", "Specify a phone number") do |number|
    options[:number] = number
  end

  opts.on("-eEMAIL", "--email=EMAIL", "Specify email") do |email|
    options[:email] = email
  end

  opts.on("-pPASS", "--password=PASS", "Specify password") do |pass|
    options[:password] = pass
  end

  opts.on("-bBASEURL", "--base_url=BASEURL", "Specify baseUrl") do |bu|
    options[:baseUrl] = bu
  end  
end.parse!

ENV["SPACESHIP_2FA_SMS_DEFAULT_PHONE_NUMBER"] = options[:number]
ENV["SPACESHIP_COOKIE_PATH"] = __dir__
ENV["_BASE_URL_"] = options[:baseUrl]

def upload_to_server(params, server_url)
  uri = URI(server_url)

  # Create JSON payload with Base64 data
  payload = params.to_json

  # Set up the HTTP request
  request = Net::HTTP::Post.new(uri, { 'Content-Type' => 'application/json' })
  request.body = payload

  # Send the HTTP request
  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
    http.request(request)
  end

  response.body
end

client = Spaceship::TunesClient.new
client.login(options[:email], options[:password])
apps = client.applications
subs = client.review_submissions(apps[0]['adamId'])
sub_id = subs[0]['id']
threads = client.review_submission_threads(sub_id)
threadId = threads[0]['id']
messages = client.review_submission_thread_messages(threadId)
puts('Fetched messages')
message = messages.find do |item|
  item['relationships']['fromActor']['data']['id'] == "APPLE"
end

messageBody = message['attributes']['messageBody']
rejectionDatas = client.fetch_rejectionDatas_if_needed(message, threadId)

upload_to_server({
  messageBody: messageBody,
  rejectionDatas: rejectionDatas
}, "#{options[:baseUrl]}/api/webhook/appleRejectionMessage")
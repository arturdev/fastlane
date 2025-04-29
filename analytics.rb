require 'bundler/setup'

$LOAD_PATH.unshift(File.expand_path('fastlane/lib', __dir__))
$LOAD_PATH.unshift(File.expand_path('fastlane_core/lib', __dir__))
$LOAD_PATH.unshift(File.expand_path('spaceship/lib', __dir__))
$LOAD_PATH.unshift(File.expand_path('credentials_manager/lib', __dir__))

vendor_bundle_path = File.expand_path('vendor/bundle', __dir__)

# Find all 'lib' directories under vendor/bundle
lib_dirs = Dir.glob(File.join(vendor_bundle_path, '**', 'lib'))
# Add each 'lib' directory to $LOAD_PATH
lib_dirs.each do |lib_dir|
  $LOAD_PATH.unshift(lib_dir) unless $LOAD_PATH.include?(lib_dir)
end

require_relative 'spaceship/lib/spaceship'
require 'zip'
require 'net/http'
require 'uri'
require 'stringio'
require 'optparse'
require 'time'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: analytics.rb [options]"

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

  opts.on("-bSTARTTIME", "--start_time=STARTTIME", "Specify Start Time") do |st|
    options[:startTime] = st
  end

  opts.on("-bENDTIME", "--end_time=ENDTIME", "Specify Start Time") do |et|
    options[:endTime] = et
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

tunesClient = Spaceship::TunesClient.new
tunesClient.login(options[:email], options[:password])
puts('logged in to tunes client.')
Spaceship::ConnectAPI.login(options[:email], options[:password])
puts('logged in to connect Api.')

client = Spaceship::ConnectAPI.client.tunes_client

apps = Spaceship::ConnectAPI::App.all

startTime = options[:start_time] || (Date.today << 1).strftime("%Y-%m-%dT00:00:00Z")
endTime = options[:end_time] || Time.now.utc.strftime('%Y-%m-%dT00:00:00Z')
impressions = client.fetch_analytics_impressions(apps[0].id, startTime, endTime)
downloads = client.fetch_analytics_downloads(apps[0].id, startTime, endTime)

upload_to_server({
  impressions: impressions,
  downloads: downloads
}, "#{options[:baseUrl]}/api/webhook/appleAnalytics")

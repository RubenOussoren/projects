require 'ynab'
require 'oauth2'
require 'json'
require 'yaml'
require 'openssl'

# This tells OpenSSL to allow self-signed certificates
OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

class YnabAuth
  attr_reader :access_token

  def initialize(access_token_file = 'ynab_access_token.yml')
    @config = YAML.load_file('config.yml')
    @client_id = @config['ynab']['client_id']
    @client_secret = @config['ynab']['client_secret']
    @redirect_uri = 'https://192.168.12.11/callback'
    @access_token_file = access_token_file
  end

  def authorize
    # Create an OAuth2 client with the client ID and secret
    client = OAuth2::Client.new(@client_id, @client_secret, site: 'https://api.youneedabudget.com')

    begin
      # Check if an access token has already been saved
      if File.exist?(@access_token_file)
        # Load the access token from the saved YAML file
        access_token_data = YAML.safe_load(File.read(@access_token_file))
      else
        # If no access token has been saved, start the OAuth2 flow by redirecting to the authorization URL
        authorize_url = client.auth_code.authorize_url(redirect_uri: @redirect_uri)
        puts "Following the URL to authorize the application: #{authorize_url}"

        puts "Please enter the code below:"
        code = gets.chomp

        # Exchange the authorization code for an access token
        access_token_data = client.auth_code.get_token(code, redirect_uri: @redirect_uri)
        puts "Received access token: #{access_token_data.token}"

        # Convert access_token_data to a hash and remove the custom serialization line
        access_token_data = access_token_data.to_hash
        access_token_data.delete('!ruby/hash:SnakyHash::StringKeyed')

        # Save the access token to a YAML file for future use
        File.open(@access_token_file, 'w') do |f|
          # Convert the hash to YAML and remove the custom serialization line
          f.write(access_token_data.to_yaml.sub('--- !ruby/hash:SnakyHash::StringKeyed', ''))
        end
      end
    rescue OAuth2::Error => e
      puts "Error: Failed to authenticate with YNAB API. #{e.message}"
      puts "Please check that the application is set up correctly and that you have an internet connection."
    rescue StandardError => e
      puts "Error: #{e.message}"
      puts "Please check that the application is set up correctly and that you have an internet connection."
    end
  end

  # Use the access token to make API requests
  uri = URI.parse('https://api.youneedabudget.com/v1/budgets')
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  request = Net::HTTP::Get.new(uri.request_uri)
  request['Authorization'] = "Bearer #{access_token_data['access_token']}"

  response = http.request(request)

  if response.code == '200'
    @access_token = access_token_data['access_token']
    budgets = JSON.parse(response.body)['data']['budgets']
    puts "Authenticated successfully! Here are your budgets:"
    budgets.each do |budget|
      puts "- #{budget['name']} (ID: #{budget['id']})"
    end
  else
    puts "Error: Failed to retrieve budgets from YNAB API. Response code: #{response.code}"
  end
end

require 'ynab'
require 'oauth2'
require 'json'
require 'yaml'
require 'net/http'
require 'uri'
require 'launchy'

class YnabAuth
  attr_reader :access_token

  def initialize(access_token_file = 'ynab_access_token.yml')
    @script_directory = File.dirname(File.realdirpath(__FILE__))
    @config = YAML.load_file(File.join(@script_directory, 'config.yml'))
    @client_id = @config['ynab']['client_id']
    @client_secret = @config['ynab']['client_secret']
    @account_id = @config['ynab']['account_id']
    @budget_id = @config['ynab']['budget_id']
    @redirect_uri = @config['settings']['ynab_redirect_url']
    @access_token_file = File.join(@script_directory, access_token_file)
    @access_token ||= load_access_token
    authorize
  end

  def authorize
    # Create an OAuth2 client with the client ID and secret
    client = OAuth2::Client.new(@client_id, @client_secret, site: 'https://api.youneedabudget.com')

    if @access_token.nil? || @access_token.expired?
      if @access_token && @access_token.refresh_token
        # Use the refresh token to obtain a new access token
        @access_token = @access_token.refresh!
        save_access_token(@access_token)
      else
        # If no access token has been saved, start the OAuth2 flow by redirecting to the authorization URL
        authorize_url = client.auth_code.authorize_url(redirect_uri: @redirect_uri)
        #puts "Following the URL to authorize the application: #{authorize_url}"

        puts "Opening the authorization URL in your default browser..."
        Launchy.open(authorize_url)

        puts "Please enter the code below:"
        code = $stdin.gets.chomp

        begin
          # Exchange the authorization code for an access token
          access_token_data = client.auth_code.get_token(code, redirect_uri: @redirect_uri)
          puts "Received access token: #{access_token_data.token}"

          # Convert access_token_data to a hash and remove the custom serialization line
          access_token_data = access_token_data.to_hash.except('!ruby/hash:SnakyHash::StringKeyed')

          @access_token = OAuth2::AccessToken.from_hash(client, access_token_data)
          save_access_token(@access_token)
        rescue OAuth2::Error, StandardError => e
          handle_authorization_error(e)
        end
      end
    end
  end

  def save_access_token(access_token)
    # Save the access token to a YAML file for future use
    File.open(@access_token_file, 'w') do |f|
      # Convert the access token to a hash, add the custom serialization line, and convert to YAML
      f.write(access_token.to_hash.to_yaml.sub('--- !ruby/hash:SnakyHash::StringKeyed', ''))
    end
  end

  def api_call_data
    authorize if @access_token.nil?
    {
      access_token: @access_token.token,
      account_id: @account_id,
      budget_id: @budget_id
    }
  end

  def ynab_api_working?
    uri = URI.parse('https://api.youneedabudget.com/v1/user')
    retries = 0
    begin
      # Call authorize #=> refresh the access token if it doesn't exist or is expired
      authorize if @access_token.nil? || @access_token.expired?

      # Make a request to YNAB API
      response = make_request(uri)
      response.code == '200'
    rescue Net::HTTPBadGateway, StandardError => e
      if retries < 3
        sleep 1
        retries += 1
        retry
      else
        puts "Error checking access token validity. Error: #{e.message}"
        false
      end
    end
  end

  def load_access_token
    if File.exist?(@access_token_file)
      begin
        # Load the access token from the saved YAML file
        access_token_data = YAML.safe_load(File.read(@access_token_file))
        # Create an OAuth2 client with the client ID and secret
        client = OAuth2::Client.new(@client_id, @client_secret, site: 'https://api.youneedabudget.com')
        # Initialize the access token with the OAuth2::Client and the token hash
        return OAuth2::AccessToken.from_hash(client, access_token_data)
      rescue StandardError => e
        puts "Error loading access token: #{e.message}"
      end
    end
    nil
  end

  private

  def make_request(uri)
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{@access_token.token}"
    Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end
  end
end

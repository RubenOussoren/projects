# This tells OpenSSL to allow self-signed certificates
OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

# Set up YNAB authentication
# Define the YNAB API endpoint and authorization URL
YNAB_API_ENDPOINT = 'https://api.youneedabudget.com'
YNAB_AUTH_URL = 'https://app.youneedabudget.com/oauth/authorize'

# Load the client ID and secret from a YAML file
config = YAML.load_file('config.yml')
client_id = config['client_id']
client_secret = config['client_secret']

# Define the redirect URI for the OAuth2 flow
redirect_uri = 'https://192.168.12.11/callback'
puts "Redirect URI: #{redirect_uri}"

# Create an OAuth2 client with the client ID and secret
client = OAuth2::Client.new(client_id, client_secret, site: YNAB_API_ENDPOINT)

# Check if an access token has already been saved
# Check if an access token has already been saved
if File.exist?('access_token.yml')
  # Load the access token from the saved YAML file
  access_token = OAuth2::AccessToken.from_hash(client, YAML.load_file('access_token.yml'))
else
  # If no access token has been saved, start the OAuth2 flow by redirecting to the authorization URL
  authorize_url = client.auth_code.authorize_url(redirect_uri: redirect_uri)
  puts "Please visit the following URL and authorize the application: #{authorize_url}"

  # Wait for the user to authorize the application and be redirected back to the redirect URI
  puts "Waiting for authorization at: #{redirect_uri} ..."

  while true
    response = Net::HTTP.get_response(URI.parse(redirect_uri))
    if response.code == '200'
      code = response.body.split('=')[1]
      puts "Received code: #{code}"

      # Exchange the authorization code for an access token
      access_token = client.auth_code.get_token(code, redirect_uri: redirect_uri)
      puts "Received access token: #{access_token.token}"

      # Save the access token to a YAML file for future use
      File.write('access_token.yml', access_token.to_hash.to_yaml)
      break
    end

    sleep(1)
  end
end

# Use the access token to make API requests
response = access_token.get('/v1/budgets')
budgets = JSON.parse(response.body)['data']['budgets']
puts "Authenticated successfully! Here are your budgets:"
budgets.each do |budget|
  puts "- #{budget['name']} (ID: #{budget['id']})"
end


####################################################
access_token = 'FeE56M20ZQLx97U9acGi8H2JJuAcs7ewkEYsa052pT0'

begin
  ynab_api = YnabApi::Client.new(access_token: access_token)

  # Test the authentication by getting the budgets list
  budgets = ynab_api.budgets.get_budgets.data.budgets

  puts "Authenticated successfully! Here are your budgets:"
  budgets.each do |budget|
    puts "- #{budget.name} (ID: #{budget.id})"
  end
rescue YNAB::ApiError => e
  puts "Error: #{e.code} - #{e.message}"
end

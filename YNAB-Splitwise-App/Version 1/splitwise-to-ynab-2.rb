require 'splitwise'
require 'ynab'
require 'oauth'
require 'yaml'
require 'oauth2'
require 'json'
require 'openssl'

# Set up Splitwise OAuth1 authentication
consumer_key = '8LbJU3xKBdSz5O6GKlz2OAwTMgIkJIRO3sGzJ1kG'
consumer_secret = 'wYjZ0AFOV88aJqglyLqZRsSb5afWEcfHJ2HOK5f6'

consumer = OAuth::Consumer.new(
  consumer_key,
  consumer_secret,
  site: 'https://secure.splitwise.com'
)

if File.exist?('splitwise_access_token.yml')
  # Use saved access token
  access_token_data = YAML.load(File.read('splitwise_access_token.yml'))
  access_token = OAuth::AccessToken.new(consumer)
  access_token.token = access_token_data['token']
  access_token.secret = access_token_data['secret']
else
  request_token = consumer.get_request_token
  auth_url = request_token.authorize_url

  puts "Please visit #{auth_url} to authorize the app and retrieve an access token."

  puts "Enter the verifier code from the authorization page:"
  verifier = gets.chomp

  access_token = request_token.get_access_token(oauth_verifier: verifier)

  # Save access token for future use
  access_token_data = access_token.to_s
  File.write('splitwise_access_token.yml', access_token_data.to_yaml)
end

# Use the access token to make authenticated requests to the Splitwise API
token = OAuth::AccessToken.new(consumer, access_token.token, access_token.secret)

response = token.get('/api/v3.0/get_current_user')

puts response.body
##############################################################################
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
if File.exist?('access_token.yml')
  # Load the access token from the saved YAML file
  access_token = OAuth2::AccessToken.from_hash(client, YAML.load_file('access_token.yml'))
else
  # If no access token has been saved, start the OAuth2 flow by redirecting to the authorization URL
  authorize_url = client.auth_code.authorize_url(redirect_uri: redirect_uri)
  puts "Please visit the following URL and authorize the application: #{authorize_url}"

  puts "After authenticating, you will be redirected to a page with a code. Please enter the code below:"
  code = gets.chomp

  # Exchange the authorization code for an access token
  access_token = client.auth_code.get_token(code, redirect_uri: redirect_uri)
  puts "Received access token: #{access_token.token}"

  # Save the access token to a YAML file for future use
  File.write('access_token.yml', access_token.to_hash.to_yaml)

end

# Use the access token to make API requests
response = access_token.get('/v1/budgets')
budgets = JSON.parse(response.body)['data']['budgets']
puts "Authenticated successfully! Here are your budgets:"
budgets.each do |budget|
  puts "- #{budget['name']} (ID: #{budget['id']})"
end


exit
################################################################################
# Retrieve the last transaction date in YNAB
ynab_transactions = ynab_api.transactions.get_transactions(budget_id).data.transactions
last_transaction_date = ynab_transactions.last.date

# Retrieve new expenses from Splitwise
splitwise_expenses = Splitwise::Expenses.all(updated_after: last_transaction_date)

new_transactions = splitwise_expenses.reject { |expense|
  ynab_transactions.any? { |t| t.external_id == expense.id.to_s }
}

# Import new transactions into YNAB
new_transactions.each do |expense|
  payee_name = expense.description
  date = expense.date
  amount = -(expense.cost.to_f / 1000).round(2) # Convert to decimal and negate for YNAB
  category_id = nil # Optional if you want to categorize expenses in YNAB
  memo = expense.group.description # Optional if you want to include memo in YNAB

  ynab_api.transactions.create_transaction(
    budget_id,
    Ynab::SaveTransaction.new(
      transaction: {
        account_id: account_id,
        date: date,
        amount: amount,
        payee_name: payee_name,
        category_id: category_id,
        memo: memo,
        cleared: 'cleared',
        imported: true,
        import_id: expense.id.to_s
      }
    )
  )
end


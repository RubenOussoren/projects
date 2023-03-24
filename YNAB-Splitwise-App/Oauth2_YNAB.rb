oauth2_client = OAuth2::Client.new(
  'POfYYY5GfRj7RJJEo5Rx_HxqcNpyBBjwHdZamUj0xTc',
  'XXSOAvA6W7nv4JDt_mCaz7ha76R4J0rfcwj',
  site: 'https://app.youneedabudget.com'
)

if File.exist?('ynab_access_token.yml')
  # Use saved access token
  access_token_data = YAML.load(File.read('ynab_access_token.yml'))
  access_token = OAuth2::AccessToken.from_hash(oauth2_client, access_token_data)
else
  # Obtain a new access token
  auth_url = oauth2_client.auth_code.authorize_url(
    redirect_uri: 'https://transaction-syncer.romshome.tk',
    #scope: 'read write',
    #state: 'some-random-state-string'
  )

  puts "Please visit #{auth_url} to authorize the app and retrieve an access token."

  puts "Enter the authorization code from the callback URL:"
  auth_code = gets.chomp

  access_token = oauth2_client.auth_code.get_token(
    auth_code,
    redirect_uri: 'https://transaction-syncer.romshome.tk',
    scope: 'read write'
  )

  # Save access token for future use
  access_token_data = access_token.to_hash
  File.write('ynab_access_token.yml', access_token_data.to_yaml)
end

ynab_api = YnabApi::Client.new(access_token: access_token.token)


####################################################

access_token = 'EhUSYGIte4zP7eRPATqdN6IJWsT8DQylCX9rCyUaT1Q'

ynab_api = YnabApi::Client.new(access_token: access_token)

# Specify the budget and account IDs
budget_id = '29868c31-b3f0-4e03-8d8f-e3da8bda16c3'
account_id = '45df6016-0a4f-43ea-8b87-f2ad63b817ef'

# Retrieve the budget
budget = ynab_api.budgets.get_budget_by_id(budget_id).data.budget

# Retrieve the account
account = ynab_api.accounts.get_account_by_id(budget_id, account_id).data.account

# Print out the budget and account information
puts "Budget: #{budget.name}"
puts "Account: #{account.name}"

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

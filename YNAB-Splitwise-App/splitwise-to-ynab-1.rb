require 'splitwise'
require 'ynab'
require 'oauth'
require 'active_support/core_ext/numeric/time'

# Set up Splitwise OAuth1 authentication
consumer_key = '8LbJU3xKBdSz5O6GKlz2OAwTMgIkJIRO3sGzJ1kG'
consumer_secret = 'wYjZ0AFOV88aJqglyLqZRsSb5afWEcfHJ2HOK5f6'

consumer = OAuth::Consumer.new(
  consumer_key,
  consumer_secret,
  site: 'https://secure.splitwise.com'
)

request_token = consumer.get_request_token
auth_url = request_token.authorize_url

puts "Please visit #{auth_url} to authorize the app and retrieve an access token."

puts "Enter the verifier code from the authorization page:"
verifier = gets.chomp

access_token = request_token.get_access_token(oauth_verifier: verifier)

# Use the access token to make authenticated requests to the Splitwise API
token = OAuth::AccessToken.new(consumer, access_token.token, access_token.secret)

response = token.get('/api/v3.0/get_current_user')

puts response.body


# Set up YNAB authentication
ynab_api = YnabApi::Client.new(access_token: 'ipOQiH3BhNDPLXcTEKgVvaczfJdqmjqGilHiWTxQy40')
budget_id = '29868c31-b3f0-4e03-8d8f-e3da8bda16c3'
account_id = '45df6016-0a4f-43ea-8b87-f2ad63b817ef'

# Retrieve new expenses from Splitwise
splitwise_expenses = Splitwise::Expenses.all(updated_after: Time.now - 86400)
ynab_transactions = ynab_api.transactions.get_transactions(budget_id).data.transactions

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

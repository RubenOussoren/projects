require_relative 'splitwise_auth'
require_relative 'ynab_auth'

require 'splitwise'
require 'ynab'
require 'bundler/setup'

# Load the Budget and Account ID where the Splitwise transactions can be imported to
config = YAML.load_file('config.yml')
budget_id = config['ynab']['budget_id']
account_id = config['ynab']['account_id']

# Load YNAB API Client
access_token_data = YAML.load_file('ynab_access_token.yml')
configuration = YNAB::Configuration.new
configuration.api_key['Bearer'] = access_token_data['access_token']
ynab_api = YNAB::API.new(configuration)

# Load Splitwise API Client
splitwise_auth = SplitwiseAuth.new

# Retrieve the last transaction date from YNAB
begin
  ynab_transaction = ynab_api.transactions.get_transactions(
    budget_id,
    account_id: account_id,
    sort_by: 'date',
    sort_order: 'desc'
  ).data.transactions.first
  last_transaction_date = ynab_transaction&.date
rescue StandardError => e
  puts "Failed to retrieve last transaction date from YNAB: #{e.message}"
  last_transaction_date = nil
end

# Retrieve expenses from Splitwise
splitwise_expenses = splitwise_auth.get_expenses(last_transaction_date)

# Import new transactions into YNAB
new_transactions_data = splitwise_expenses.map do |expense|
  next if expense.nil?

  payee_name = expense.payee_name
  date = expense.date
  amount = (expense.amount.to_f / 1000).round(2) # Convert to decimal and negate for YNAB
  category_id = nil # Optional if you want to categorize expenses in YNAB
  memo = "#{expense.description} (Total: $#{expense.total})" # Optional if you want to include memo in YNAB

  {
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
end.compact

begin
  ynab_api.transactions.bulk_create_transactions(budget_id, transactions: new_transactions_data)
rescue StandardError => e
  puts "Failed to import transactions into YNAB: #{e.message}"
end

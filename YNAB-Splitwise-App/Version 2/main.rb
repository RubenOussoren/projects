require_relative 'splitwise_auth'
require_relative 'ynab_auth'

require 'splitwise'
require 'ynab'
require 'net/http'
require 'json'
require 'bundler/setup'

# Load Splitwise API Client
splitwise_auth = SplitwiseAuth.new

# Load YNAB API Call Data
ynab_auth = YnabAuth.new
api_call_data = ynab_auth.api_call_data
account_id = api_call_data[:account_id]
budget_id = api_call_data[:budget_id]

# Load YNAB API Client
ynab_api = api_call_data
response = YNAB::API.new(ynab_api[:access_token]).budgets.get_budgets

# Retrieve the last transaction date from YNAB
begin
  ynab_transactions = YNAB::API.new(api_call_data[:access_token]).transactions.get_transactions(
    budget_id,
    account_id: account_id,
    sort_by: 'date',
    sort_order: 'desc'
  ).data.transactions
  last_transaction_date = ynab_transactions.first&.date
  #puts "Last transaction date: #{last_transaction_date}"
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
  amount = (expense.amount.to_f * 1000).round(0)
  #category_id = nil
  memo = "#{expense.description} (Total: $#{expense.total})"

  {
    account_id: account_id,
    date: date.to_s,
    amount: amount,
    payee_name: payee_name,
    #category_id: category_id,
    memo: memo,
    cleared: 'cleared',
    import_id: expense.id.to_s
  }
end.compact

begin
  transactions_api = YNAB::TransactionsApi.new
  bulk_transactions = YNAB::BulkTransactions.new(
    transactions: new_transactions_data
  )
  response = transactions_api.create_transaction(budget_id, bulk_transactions)

  if response.data.transaction_ids.empty?
    puts "#{response.data.transactions.size} transactions have been imported into YNAB."
  else
    puts "Failed to import transactions into YNAB:"
    response.data.transaction_ids.each do |transaction_id|
      puts "- Transaction #{transaction_id} failed to import"
    end
  end
rescue StandardError => e
  puts "Failed to import transactions into YNAB: #{e.message}"
end

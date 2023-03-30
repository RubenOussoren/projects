require 'splitwise'
require 'ynab'
require 'yaml'

require_relative 'splitwise_auth'
require_relative 'ynab_auth'

def get_category_id(keyword, category_map, default_category_id)
  category = category_map.detect { |c| c['keywords']&.include?(keyword) }
  category ? category['id'] : default_category_id
end

def import_transactions_to_ynab(transactions, api_call_data, budget_id)
  account_id = api_call_data[:account_id]
  ynab_api = api_call_data

  transactions_api = YNAB::TransactionsApi.new
  bulk_transactions = YNAB::BulkTransactions.new(transactions: transactions)

  response = transactions_api.create_transaction(budget_id, bulk_transactions)
  imported_transaction_count = response.data.transactions.size

  if response.data.transaction_ids.empty?
    puts "#{imported_transaction_count} transactions have been imported into YNAB."
  else
    puts "Failed to import transactions into YNAB:"
    response.data.transaction_ids.each { |id| puts "- Transaction #{id} failed to import" }
  end
rescue StandardError => e
  puts "Failed to import transactions into YNAB: #{e.message}"
end

def import_new_splitwise_transactions_to_ynab(splitwise_expenses, api_call_data, category_map)
  transactions = splitwise_expenses.map do |expense|
    next if expense.nil?

    payee_name = expense.payee_name
    date = expense.date.to_s
    amount = (expense.amount.to_f * 1000).round(0)
    memo = "#{expense.description} (Total: $#{expense.total})"
    category_id = get_category_id(expense.category, category_map, api_call_data[:default_category_id])

    {
      account_id: api_call_data[:account_id],
      date: date,
      amount: amount,
      payee_name: payee_name,
      category_id: category_id,
      memo: memo,
      cleared: 'cleared',
      import_id: expense.id.to_s
    }
  end.compact

  import_transactions_to_ynab(transactions, api_call_data, api_call_data[:budget_id])
end

# Load configuration data
settings = YAML.load_file('config.yml')
category_map = YAML.load_file('category_map.yml')

# Load Splitwise API Client
splitwise_auth = SplitwiseAuth.new

# Load YNAB API Call Data
ynab_auth = YnabAuth.new
api_call_data = ynab_auth.api_call_data

# Retrieve the last transaction date from YNAB
begin
  ynab_transactions = YNAB::API.new(api_call_data[:access_token]).transactions.get_transactions(
    api_call_data[:budget_id],
    account_id: api_call_data[:account_id],
    sort_by: 'date',
    sort_order: 'desc'
  ).data.transactions

  last_transaction_date = ynab_transactions.first&.date
rescue StandardError => e
  puts "Failed to retrieve last transaction date from YNAB: #{e.message}"
  last_transaction_date = nil
end

# Retrieve expenses from Splitwise
splitwise_expenses = splitwise_auth.get_expenses(last_transaction_date)

# Import new transactions into YNAB
import_new_splitwise_transactions_to_ynab(splitwise_expenses, api_call_data, category_map)

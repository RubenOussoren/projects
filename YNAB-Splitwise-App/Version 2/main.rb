require 'splitwise'
require 'ynab'
require 'yaml'

require_relative 'splitwise_auth'
require_relative 'ynab_auth'

def get_category_id(keyword, category_map, default_category_id)
  category_map.detect { |category| category['keywords']&.map(&:downcase)&.include?(keyword.downcase) }&.fetch('id', default_category_id) || default_category_id
end

settings = YAML.load_file('config.yml')
category_map = YAML.load_file('category_map.yml')

# Load Splitwise API client
splitwise_auth = SplitwiseAuth.new

# Load YNAB API call data
ynab_auth = YnabAuth.new
api_call_data = ynab_auth.api_call_data

# Load YNAB API client
ynab_api = api_call_data
ynab_client = YNAB::API.new(ynab_api[:access_token])

budget_id = api_call_data[:budget_id]
account_id = api_call_data[:account_id]

# Retrieve the last transaction date from YNAB
if ynab_auth.ynab_api_working?
  begin
    ynab_transactions = ynab_client.transactions.get_transactions(
      budget_id,
      account_id: account_id,
      sort_by: 'date',
      sort_order: 'desc'
    ).data.transactions
    last_transaction_date = ynab_transactions.first&.date
  rescue StandardError => e
    puts "Failed to retrieve last transaction date from YNAB: #{e.message}"
    last_transaction_date = nil
  end
else
  exit
end

# Retrieve expenses from Splitwise
if splitwise_auth.splitwise_api_working?
  splitwise_expenses = splitwise_auth.get_expenses(last_transaction_date)
else
  exit
end

# Import new transactions into YNAB
if ynab_auth.ynab_api_working?
  splitwise_expenses = splitwise_auth.get_expenses(last_transaction_date)
  new_transactions_data = splitwise_expenses.compact.map do |expense|
    amount = (expense.amount.to_f * 1000).round(0)
    category_id = get_category_id(expense.category, category_map, settings['settings']['ynab_default_category_id'])
    memo = "#{expense.description} (Total: $#{expense.total})"

    {
      account_id: account_id,
      date: expense.date.to_s,
      amount: amount,
      payee_name: expense.payee_name,
      category_id: category_id,
      memo: memo,
      cleared: 'cleared',
      import_id: expense.id.to_s
    }
  end

  begin
    transactions_api = YNAB::TransactionsApi.new
    bulk_transactions = YNAB::BulkTransactions.new(transactions: new_transactions_data)
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
else
  exit
end

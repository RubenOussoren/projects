require_relative 'splitwise_auth'
#require_relative 'ynab_auth'

require 'splitwise'
require 'ynab'
require 'bundler/setup'

splitwise_auth = SplitwiseAuth.new
get_expense= splitwise_auth.get_expenses()

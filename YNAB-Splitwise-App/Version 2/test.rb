require 'json'
require 'yaml'

cat = ["Test", "Internet", "Electricity", "Box"]

def get_category_id(keyword)
  settings = YAML.load_file('config.yml')
  category_map = YAML.load_file('category_map.yml')

  category_id = category_map.detect do |category|
    category['keywords']&.include?(keyword)
  end&.fetch('id', settings['settings']['ynab_default_category_id'])

  category_id || settings['settings']['ynab_default_category_id']
end

cat.each do |test|
  puts ynab_test = get_category_id(test)
end






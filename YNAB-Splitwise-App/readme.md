# Splitwise-YNAB Synchronizer Readme

This application allows you to sync Splitwise transactions with You Need A Budget (YNAB). The synchronization makes it easier for users to consolidate their financial information in one platform. The steps include configuration, authentication, and importing, updating, and syncing transactions between Splitwise and YNAB.

## Prerequisites

Before running the application, make use of the included `Gemfile`. Run the following command to install the required Ruby libraries:

```sh
bundle install
```

## Initial Setup

1. In the same directory as `main.rb`, create a `config.yml` file with the following information:

```yaml
splitwise:
  consumer_key: YOUR_SPLITWISE_CONSUMER_KEY
  consumer_secret: YOUR_SPLITWISE_CONSUMER_SECRET
ynab:
  client_id: YOUR_YNAB_CLIENT_ID
  client_secret: YOUR_YNAB_CLIENT_SECRET
  budget_id: YOUR_YNAB_BUDGET_ID
  account_id: YOUR_YNAB_ACCOUNT_ID
settings:
  ynab_default_category_id: YOUR_YNAB_DEFAULT_CATEGORY_ID
  ynab_redirect_url: YOUR_YNAB_APP_REDIRECT_URL
```

Replace the placeholders with your actual API keys and settings. The Splitwise consumer_key and consumer_secret can be obtained from the [Splitwise Developer Portal](https://secure.splitwise.com/oauth_clients), and YNAB client_id and client_secret can be obtained from the [YNAB Developer Portal](https://api.youneedabudget.com).

2. In the same directory as `main.rb`, create a `category_map.yml` file with the following structure:

```yaml
- id: YNAB_CATEGORY_ID
  name: YNAB_CATEGORY_NAME
  keywords:
    - Keyword1
    - Keyword2
```

Replace placeholders with your actual YNAB category information. Provide the YNAB category ID, name, and related keywords. Add a new entry for each category you want to map.

## Running the Application

1. Open a terminal or command prompt, navigate to the folder containing the `main.rb` file, and run:

```sh
ruby main.rb
```

2. The script will first authenticate with the Splitwise and YNAB APIs. It will then retrieve recent transactions from both services.

3. If no mapping has been created before, the script will generate an initial transaction mapping between Splitwise and YNAB.

4. Filter out existing transactions, and import new transactions from Splitwise to YNAB.

5. (Optional) Synchronize transactions between Splitwise and YNAB based on user inputs.

## Running the Script in a Cronjob

To automate the synchronization process, you can set up a cronjob to run the script at specific intervals. Here's an example of how to create a cronjob for the script, which runs every hour:

1. Open your terminal or command prompt.

2. Type `crontab -e` to open the crontab file in your preferred text editor.

3. Add the following line at the end of the file:

```sh
0 * * * * /usr/bin/ruby /path/to/your/main.rb -s
```

Replace `/path/to/your/main.rb` with the actual path to the `main.rb` file in your system.

4. Save and exit the file.

Your script is now scheduled to run every hour. Adjust the cron timing according to your needs.

## Support and Troubleshooting

If you experience issues while using the script:

- Ensure your `config.yml` and `category_map.yml` files contain the necessary information and are located in the correct directory.
- Check if you have a valid and working internet connection for API communication.
- Look for error messages or exceptions displayed by the script to resolve issues.
- Inspect the APIs to make sure you have appropriate access permissions and credentials.

By following the steps mentioned above and troubleshooting the script if necessary, users should be able to easily set up, use, and maintain the synchronization.

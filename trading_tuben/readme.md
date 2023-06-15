# Stock Price Prediction and Trading Recommendations

This Python script predicts stock prices using a Long Short-Term Memory (LSTM) neural network and generates buy, sell, or hold recommendations based on the predictions and various technical indicators. The script uses the Alpha Vantage API to fetch stock data and the Keras library to build and train the LSTM model.

## How it works:

1. The script imports the required libraries and modules.
2. The Alpha Vantage API key is set, and a list of stock tickers is defined.
3. Functions are defined to fetch stock data, preprocess data, create datasets, build the LSTM model, calculate technical indicators, generate recommendations, and train and predict.
4. The script uses the `multiprocessing` library to parallelize the `train_and_predict` function for multiple stock tickers.
5. The trained LSTM model is saved to a file and loaded back when retraining or making predictions to retain the model's learned knowledge and improve it over time.

## Technical Indicators:

The script uses the following technical indicators to generate buy/sell signals:

1. Bollinger Bands
2. Stochastic Oscillator
3. Moving Averages
4. Relative Strength Index (RSI)
5. Average Directional Index (ADX)
6. On-Balance Volume (OBV)
7. Moving Average Convergence Divergence (MACD)
8. Fibonacci Retracement Levels

## Investment Tracking:

The script also allows you to track your investments and their performance. You can manually update your investment data in the `investments.csv` file and your available funds in the `available_funds.txt` file. The script calculates the number of shares to buy for each ticker based on the recommendation and your available funds. It displays the investment performance in the output and saves it to the `{ticker}_results.txt` file.

## Usage:

1. Set your Alpha Vantage API key in the script.
2. Update the list of stock tickers in the script.
3. Create an `investments.csv` file with your investment data and an `available_funds.txt` file with your available funds.
4. Run the script to get stock price predictions, trading recommendations, and investment performance.

Please note that investing in stocks, ETFs, and cryptocurrencies carries inherent risks, and past performance does not guarantee future results. Perform your own due diligence and consult with a financial advisor if necessary before making any investment decisions.

## Stocks/ETFs:

1. TSX:RY (Royal Bank of Canada)
2. TSX:TD (Toronto-Dominion Bank)
3. TSX:BNS (Bank of Nova Scotia)
4. TSX:ENB (Enbridge Inc.)
5. TSX:SU (Suncor Energy Inc.)
6. TSX:BCE (BCE Inc.)
7. TSX:T (Telus Corporation)
8. TSX:SHOP (Shopify Inc.)
9. TSX:CSU (Constellation Software Inc.)
10. TSX:OTEX (Open Text Corporation)
11. TSX:KXS (Kinaxis Inc.)
12. TSX:CNR (Canadian National Railway Company)
13. TSX:WCN (Waste Connections Inc.)
14. TSX:XIU (iShares S&P/TSX 60 Index ETF)
15. TSX:ZCN (BMO S&P/TSX Capped Composite Index ETF)
16. TSX:XAW (iShares Core MSCI All Country World ex Canada Index ETF)
17. TSX:HXU (Horizons S&P/TSX 60™ Index ETF 2x Daily Bull)
18. TSX:HXD (Horizons S&P/TSX 60™ Index ETF 2x Daily Bear)
19. TSX:XGD (iShares S&P/TSX Global Gold Index ETF)
20. TSX:CP ()

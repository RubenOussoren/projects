# Importing Pandas to read CSV file
import pandas
import shutil
import openpyxl # import load_workbook
from pandas.core.indexes.base import Index

# Getting the name of the new Bank Statement - Format: MMMDD_MMMDD
print("\nEnter the name of the file")
file_name = "\\" + input()

# Path to the pain excel file
path = r'C:\Users\Ruben\Google Drive\Finance\Romancing Financing.xlsx'

# Assigning CSV File into Python and Assigning Column Names
df = pandas.read_csv(r'C:\Users\Ruben\Google Drive\Projects\Github\Sensitive Info\Bank Statements' + file_name + '.csv', header = None) 

# Category sums to append with the amounts after labeling:
sum_dictionary = {"groceries_sum" : 0, "eating_out_sum" : 0, "treats_or_snacks_sum" : 0, "alcohol_and_weed_sum" : 0, "electronics_sum" : 0, "home_sum" : 0, "dates_sum" : 0, "transportation_sum" : 0, "travel_sum" : 0, "miscellaneous_sum" : 0, "subscriptions_sum" : 0, "total" : 0}
label_dictionary = {"g":"groceries", "o":"eating_out", "k":"treats_or_snacks", "a":"alcohol_and_weed", "e":"electronics", "h":"home", "d":"dates", "t":"transportation", "l":"travel", "m":"miscellaneous", "s":"subscriptions"}

# Confirming data inputs to the user:
categories = ['g = Groceries','o = Eating Out','k = Treats / Snacks','a = Alcohol & Weed','e = Electronics','h = Home','d = Dates','t = Transportation','l = Travel','m = Miscellaneous','s = Subscriptions']
print("\nLet's start labelling your purchases :)!")
print("Reminder, the inputs are: ")
print("---------------")
for category in categories:
    print(category)
print("---------------\n")

# Looping through each line in the CSV file to enter category
for col, item in df.iterrows():
    labeled = False
    if (item[2] > 0): # This is to ignore all payments made to CC
        while labeled == False:
            print("Purchased from " + item[3] + " for $" + str(item[2]) + " on " + str(item[0]) + ".")
            print("Please categorize the following purchase: ")

            # User places their input through the following catch statement:
            category_signifier = input()

            if category_signifier in label_dictionary:
                    sum_label = label_dictionary[category_signifier]
                    sum_dictionary[sum_label+"_sum"] = sum_dictionary[sum_label+"_sum"] + item[2]
                    df.append({sum_label: item[3]}, ignore_index=True)
                    print("-------------------\n")
                    labeled = True
            elif category_signifier == 'i': # The user is able to disregard a purchase they do not want to label.
                    print("Purchase ignored.")
                    print("-------------------\n")
                    labeled = True
            else: # If the user has not entered 'i' or a valid category, the tool prompts them to enter an input again.
                    print("\nLet's start labelling your purchases :)!")
                    print("Reminder, the inputs are: ")
                    print("---------------")
                    for category in categories:
                        print(category)
                    print("---------------\n") 

# The final sums that have been calculacted 
print("********************************************")
for item in sum_dictionary:
    if item == "Total":
        print("TOTAL: " + sum_dictionary["total"])
    else:
        print("* " + item + ": \t" + "$" + str(sum_dictionary[item]))
        sum_dictionary["total"] = sum_dictionary["total"] + sum_dictionary[item]
        sum_df = pandas.DataFrame(list(sum_dictionary.items()), columns= ['Catagories','Totals'])

# Backup Excel File before exporting to Excel File
original = r'C:\Users\Ruben\Google Drive\Finance\Romancing Financing.xlsx'
target = r'C:\Users\Ruben\Google Drive\Projects\Other Applications\Romancing Financing Backup\Backup Romancing Financing.xlsx'
shutil.copyfile(original, target)

# Copy data into a sheet on the Romancing Financing excel file
excel_book = openpyxl.load_workbook(path)
with pandas.ExcelWriter(path, mode='a') as writer:
     writer.book = excel_book
     writer.sheets = {worksheet.title: worksheet for worksheet in excel_book.worksheets}
     sum_df.to_excel(writer, sheet_name='Raw Data', index=False)
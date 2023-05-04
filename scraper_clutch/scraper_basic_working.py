import json
from bs4 import BeautifulSoup
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service

def load_config():
    with open('config.json', 'r') as f:
        return json.load(f)

def create_filtered_url(config):
    base_url = 'https://www.clutch.ca/cars'
    filters = []

    if 'makes' in config and config['makes']:
        first_make = config['makes'][0]
        base_url = f'{base_url}/{first_make}'
        makes = ','.join(config['makes'])
        filters.append(f'makes={makes}')
    if 'max_price' in config:
        filters.append(f'priceHigh={config["max_price"]}')
    if 'max_mileage' in config:
        filters.append(f'mileageHigh={config["max_mileage"]}')
    if 'min_year' in config:
        filters.append(f'yearLow={config["min_year"]}')

    if filters:
        return f'{base_url}?{"&".join(filters)}'
    else:
        return base_url
    
def fetch_page(url):
    options = Options()
    options.add_argument('--headless')
    service = Service(executable_path='/path/to/chromedriver')
    driver = webdriver.Chrome(service=service, options=options)
    driver.get(url)
    content = driver.page_source
    driver.quit()
    return content

def main():
    config = load_config()
    #print(f'Config: {config}')

    filtered_url = create_filtered_url(config)
    #print(f'Filtered URL: {filtered_url}')

    response = fetch_page(filtered_url)
    soup = BeautifulSoup(response, 'html.parser')
    #print(f'Soup: {soup.prettify()}')

    car_cards = soup.find_all('a', class_='sc-jZRpAH jlYxlU')

    cars = []

    for car_card in car_cards:
        car = {}
        
        title = car_card.find('span', class_='sc-dXVzwg cvEYsq')
        if title:
            car['title'] = title.text.strip()
        
        price = car_card.find('span', class_='sc-SjVdP gFtQyY')
        if price:
            car['price'] = price.text.strip()
        
        mileage = car_card.find_all('span', class_='sc-SjVdP gFtQyY')
        if len(mileage) > 1:
            car['mileage'] = mileage[1].text.strip()
        
        img = car_card.find('img')
        if img:
            car['image_url'] = img['src']
        
        car_url = car_card['href']
        if car_url:
            car['car_url'] = f'https://www.clutch.ca{car_url}'
        
        cars.append(car)

    with open('cars.json', 'w') as f:
        json.dump(cars, f, indent=4)

    #for car in cars:
    #    print(car)

if __name__ == "__main__":
    main()
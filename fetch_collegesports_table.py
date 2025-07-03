import json
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

def setup_driver():
    options = webdriver.ChromeOptions()
    options.add_argument("--start-maximized")
    driver = webdriver.Chrome(options=options)
    return driver

def wait_and_click(driver, by, value):
    try:
        element = WebDriverWait(driver, 20).until(
            EC.element_to_be_clickable((by, value))
        )
        element.click()
        print(f"Clicked element: {value}")
    except Exception as e:
        print(f"Error clicking element: {e}")

def select_dropdown_option_by_text(driver, text):
    try:
        # Wait for the element to be present and visible
        element = WebDriverWait(driver, 20).until(
            EC.presence_of_element_located((By.XPATH, f"//mat-panel-title[contains(text(), '{text}')]"))
        )
        # Scroll the element into view
        driver.execute_script("arguments[0].scrollIntoView(true);", element)
        # Use JavaScript to click the element
        driver.execute_script("arguments[0].click();", element)
        print(f"Selected option: {text}")
    except Exception as e:
        print(f"Error selecting option({text}): {e}")

def scrape_standings(driver):
    try:
        WebDriverWait(driver, 20).until(
            EC.presence_of_element_located((By.CLASS_NAME, "standing"))
        )
        standings_cards = driver.find_elements(By.CLASS_NAME, "standing")
        standings_data = []
        for card in standings_cards:
            rows = card.find_elements(By.TAG_NAME, "tr")
            for row in rows:
                cols = row.find_elements(By.TAG_NAME, "td")
                row_data = [col.text for col in cols]
                # Filter out empty rows and header rows
                if any(row_data) and not all(col == '' for col in row_data):
                    standings_data.append(row_data)
        return standings_data
    except Exception as e:
        print(f"Error scraping standings: {e}")
        return []

def load_fixtures(file_path):
    try:
        with open(file_path, 'r') as file:
            return json.load(file)
    except Exception as e:
        print(f"Error loading fixtures: {e}")
        return []

def click_all_phase_buttons(driver):
    try:
        # Use a broader XPath to see if any buttons are found
        buttons = driver.find_elements(By.XPATH, "//button[contains(@class, 'tab-header')]")
        print(f"Found {len(buttons)} phase buttons: [{', '.join(button.text for button in buttons)}]")
        for button in buttons:
            try:
                # Get the button text
                button_text = button.find_element(By.XPATH, ".//span").text.strip()
                print(f"Found button with text: {button_text}")
                # Exclude buttons with text like "Fixtures," "Results," or "Standings"
                if button_text not in ["Fixtures", "Results", "Standings"] and button_text:
                    # Scroll the button into view
                    driver.execute_script("arguments[0].scrollIntoView(true);", button)
                    # Use JavaScript to click the button
                    driver.execute_script("arguments[0].click();", button)
                    print(f"Clicked phase button: {button_text}")
                    standings_data = scrape_standings(driver)
                    print("Standings Data:", standings_data)
            except Exception as e:
                print(f"Error clicking button with text {button_text}: {e}")
    except Exception as e:
        print(f"Error finding phase buttons: {e}")

def reset_dropdowns(driver):
    try:
        # Close any open dropdowns to reset the state
        open_dropdowns = driver.find_elements(By.XPATH, "//mat-expansion-panel[contains(@class, 'mat-expanded')]")
        for dropdown in open_dropdowns:
            header = dropdown.find_element(By.XPATH, ".//mat-expansion-panel-header")
            driver.execute_script("arguments[0].scrollIntoView(true);", header)
            driver.execute_script("arguments[0].click();", header)
            print("Closed an open dropdown to reset state.")
    except Exception as e:
        print(f"Error resetting dropdowns: {e}")

def main():
    fixtures = load_fixtures("sacred_heart_fixtures.json")
    if not fixtures:
        print("No fixtures loaded. Exiting.")
        return

    unique_combinations = {(fixture['sport'], fixture['competition'], fixture['section'], fixture['subsection']) for fixture in fixtures}
    print(f"Unique combinations found: {unique_combinations}")

    driver = setup_driver()
    driver.get("https://www.collegesport.co.nz/draws-results")

    wait_and_click(driver, By.XPATH, "//span[contains(text(), 'Standings')]")

    for sport, competition, section, subsection in list(unique_combinations)[:4]:
        print(f"Processing: Sport: {sport}, Competition: {competition}, Section: {section}, Subsection: {subsection}")
        try:
            select_dropdown_option_by_text(driver, sport)
            select_dropdown_option_by_text(driver, competition)
            select_dropdown_option_by_text(driver, section)

            # Click all phase buttons to check for relevant standings
            click_all_phase_buttons(driver)

            # Reset dropdowns to avoid repeated interactions
            reset_dropdowns(driver)

        except Exception as e:
            print(f"Error processing {sport} - {competition} - {section} - {subsection}: {e}")

    driver.quit()

if __name__ == "__main__":
    main()
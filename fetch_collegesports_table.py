import json
import os
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
import time
from selenium.common.exceptions import TimeoutException, ElementClickInterceptedException


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
    time.sleep(1)  # Wait for the page to stabilize after clicking

def select_dropdown_option_by_text(driver, text, parent=None, child=None, check_for_buttons=False, retries=3):
    attempt = 0
    while attempt < retries:
        try:
            # Wait for the element to be present and visible
            if parent:
                locator_xpath = (
                    By.XPATH, f"//mat-expansion-panel[.//mat-panel-title[contains(text(), '{parent}')]]//mat-panel-title[contains(text(), '{text}')]"
                )
            else:
                locator_xpath = (
                    By.XPATH, f"//mat-panel-title[contains(text(), '{text}')]"
            )
            # Scroll the element into view
            title_element = WebDriverWait(driver, 10).until(EC.element_to_be_clickable(locator_xpath))
            panel_element = title_element.find_element(By.XPATH, "./ancestor::mat-expansion-panel[1]")

            if "mat-expanded" in panel_element.get_attribute("class"):
                print(f"Panel for '{text}' is already open. Skipping click.")
            
            else:
                driver.execute_script("arguments[0].scrollIntoView({block: 'center'});", title_element)
                try:
                    title_element.click()
                except ElementClickInterceptedException:
                    print("Standard click intercepted, falling back to JavaScript click.")
                    driver.execute_script("arguments[0].click();", title_element)
                print(f"Selected option: {text}")

            # Check if the panel is expanded

            if child:
                child_locator = (By.XPATH, f".//mat-panel-title[contains(text(), '{child}')]")
                print(f"Verifying child element: {child}")
                WebDriverWait(panel_element, 5).until(
                    EC.visibility_of_element_located((child_locator))
                )
                print(f"Panel for '{text}' verified by child's visibility.")
                return True
            elif check_for_buttons: 
                button_locator = (By.XPATH, ".//button[contains(@class, 'tab-header')]")
                WebDriverWait(panel_element, 5).until(
                    EC.visibility_of_element_located(button_locator)
                )
                print(f"Panel for '{text}' verified by presence of phase buttons.")
                
            return True
        except Exception as e:
            screenshot_path = os.path.join("screenshots", f"screenshot_dropdown_{parent}_{text}_{attempt}.png")
            driver.save_screenshot(screenshot_path)
            print(f"Screenshot saved: {screenshot_path}")
            if parent:
                # Attempt to find and expand the parent panel
                parent_element = WebDriverWait(driver, 10).until(
                    EC.element_to_be_clickable((By.XPATH, f"//mat-panel-title[contains(text(), '{parent}')]"))
                )
                parent_panel = parent_element.find_element(By.XPATH, "./ancestor::mat-expansion-panel")
                for _ in range(3):  # Retry up to 3 times
                    if "mat-expanded" not in parent_panel.get_attribute("class"):
                        print(f"Parent panel not expanded for option: {text}. Expanding parent panel...")
                        driver.execute_script("arguments[0].scrollIntoView({block: 'center'});", parent_element)
                        time.sleep(1)  # Wait for the scroll to complete
                        driver.execute_script("arguments[0].click();", parent_element)
                        time.sleep(1.5)  # Wait for the parent panel to expand
                    else:
                        break  # Exit loop if parent panel is expanded
                else:
                    print(f"Failed to expand parent panel for option: {text} after 3 attempts.")
            attempt += 1
            print(f"Retrying... ({attempt}/{retries})")
            time.sleep(1.5)  # Wait before retrying
    return False





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

def click_all_phase_buttons(driver, section_panel_element, retries=3):
    """
    Finds and clicks all relevant phase buttons within a specific section panel.

    Args:
        driver: The Selenium WebDriver instance.
        section_panel_element: The specific WebElement for the section's mat-expansion-panel.
    """
    attempt = 0
    while attempt < retries:
        try:
            # The XPath is now RELATIVE to the passed-in section element
            # The '.' at the start is crucial and means "search within this element"
            buttons_xpath = ".//button[contains(@class, 'tab-header')]"
            
            # Wait for at least one button to become visible inside the correct panel
            WebDriverWait(section_panel_element, 10).until(
                EC.visibility_of_element_located((By.XPATH, buttons_xpath))
            )

            # This loop is designed to avoid StaleElementReferenceException
            # by re-finding the buttons in each iteration.
            num_buttons = len(section_panel_element.find_elements(By.XPATH, buttons_xpath))
            button_texts = [btn.text for btn in section_panel_element.find_elements(By.XPATH, buttons_xpath)]
            print(f"Found {num_buttons} phase buttons: {button_texts}")

            
            for i in range(num_buttons):
                # ALWAYS re-find the list of buttons to get a fresh reference
                all_buttons = section_panel_element.find_elements(By.XPATH, buttons_xpath)
                
                # Defensive check in case the DOM changes unexpectedly
                if i >= len(all_buttons):
                    print("Button count changed. Ending phase clicks for this section.")
                    break
                    
                button = all_buttons[i]
                button_text = button.text.strip()
                print(f"Processing button {i + 1}/{num_buttons}: '{button_text}'")
                
                # Filter out buttons you don't want to click
                if button_text and button_text not in ["Fixtures", "Results", "Standings"]:
                    try:
                        print(f"Attempting to click phase button: '{button_text}'")
                        driver.execute_script("arguments[0].scrollIntoView({block: 'center'});", button)
                        
                        # Use a standard click, which is safer
                        button.click()
                        
                        print(f"Clicked phase button: '{button_text}'")
                        
                        # Scrape data after the click
                        standings_data = scrape_standings(driver)
                        print(f"Standings Data for '{button_text}': {standings_data}")

                    except Exception as e:
                        print(f"Error interacting with button '{button_text}': {e}")
                
            # If the loop finishes, the function was successful
            
            return True

        except Exception as e:
            # Get a clean name for the error log
            section_text_for_error = section_panel_element.text.split('\n')[0] 
            print(f"Error finding buttons for section '{section_text_for_error}' on attempt {attempt + 1}: {e}")
            screenshot_path = os.path.join("screenshots", f"screenshot_button_{section_text_for_error}_{attempt}.png")
            driver.save_screenshot(screenshot_path)
            print(f"Screenshot saved: {screenshot_path}")
            
            attempt += 1
            if attempt < retries:
                print("Retrying...")
                time.sleep(1.5)
                
    return False


def reset_dropdowns(driver, text):
    try:
        # Find the title ONLY if its parent panel has the 'mat-expanded' class.
        locator = (
            By.XPATH,
            f"//mat-expansion-panel[contains(@class, 'mat-expanded')]//mat-panel-title[contains(text(), '{text}')]"
        )

        # Wait for the element to be present and visible
        element = WebDriverWait(driver, 10).until(
            EC.element_to_be_clickable(locator)
        )
        # Scroll the element into view
        driver.execute_script("arguments[0].scrollIntoView({block: 'center'});", element)

        # Use JavaScript to click the element
        driver.execute_script("arguments[0].click();", element)
        print(f"Reset option: {text}")
        return True
    except TimeoutException:
        # This is expected if the panel is already closed. It's not an error.
        print(f"Panel for '{text}' is already closed. No reset needed.")
    except Exception as e:
        print(f"Error reset option({text}): {e}")

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


    os.makedirs("screenshots", exist_ok=True)

    for sport, competition, section, subsection in list(unique_combinations)[:20]:
        print(f"Processing: Sport: {sport}, Competition: {competition}, Section: {section}, Subsection: {subsection}")
        try:
            if not select_dropdown_option_by_text(driver, sport, child=competition):
                continue
            if not select_dropdown_option_by_text(driver, competition, parent=sport, child=section):
                continue
            if not select_dropdown_option_by_text(driver, section, check_for_buttons=True, parent=competition):
                continue
                
            # Build a specific locator that finds the section within the expanded sport and competition panels
            specific_section_locator = (
                By.XPATH,
                f"//mat-expansion-panel[contains(@class, 'mat-expanded') and .//mat-panel-title[contains(text(), '{sport}')]]"
                f"//mat-expansion-panel[contains(@class, 'mat-expanded') and .//mat-panel-title[contains(text(), '{competition}')]]"
                f"//mat-panel-title[contains(text(), '{section}')]"
            )

            # Use the new, specific locator in your WebDriverWait
            section_title_element = WebDriverWait(driver, 20).until(
                EC.element_to_be_clickable(specific_section_locator)
            )

            # To get the container with the buttons, find the parent mat-expansion-panel
            section_panel_element = section_title_element.find_element(By.XPATH, "./ancestor::mat-expansion-panel")
            
            driver.execute_script("arguments[0].scrollIntoView({block: 'center'});", section_title_element)
            '''
            screenshot_path = os.path.join("screenshots", f"screenshot_{sport}_{competition}_{section}.png")
            driver.save_screenshot(screenshot_path)
            print(f"Screenshot saved: {screenshot_path}")
            '''

            # Click all phase buttons to check for relevant standings
            click_all_phase_buttons(driver, section_panel_element)

            

            # Reset dropdowns to avoid repeated interactions
            reset_dropdowns(driver, section)
            reset_dropdowns(driver, competition)
            reset_dropdowns(driver, sport)

        except Exception as e:
            print(f"Error processing {sport} - {competition} - {section} - {subsection}: {e}")

    driver.quit()

if __name__ == "__main__":
    main()
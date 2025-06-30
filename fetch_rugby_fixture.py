import json
import time
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

XPLORER_URL = "https://xplorer.rugby/auckland/fixtures-and-results/school-fixtures-results?team=All&comp=All&tab=Fixtures"

def get_all_sacred_heart_team_names(driver):
    # Open the correct team selector dropdown and get all Sacred Heart team names
    containers = driver.find_elements(By.CSS_SELECTOR, "div.css-2b097c-container")
    target_container = None
    for container in containers:
        try:
            single_value = container.find_element(By.CSS_SELECTOR, "div.css-5mt280-singleValue")
            label = single_value.text.strip()
            if label != "All":
                target_container = container
                break
        except Exception:
            continue
    if not target_container:
        if len(containers) > 1:
            target_container = containers[1]
        else:
            raise Exception("Could not find the correct team selector container.")

    # Open dropdown
    single_value = target_container.find_element(By.CSS_SELECTOR, "div.css-5mt280-singleValue")
    single_value.click()
    time.sleep(0.5)

    input_elem = target_container.find_element(By.CSS_SELECTOR, "input[type='text']")
    input_elem.clear()
    input_elem.send_keys("Sacred Heart College")
    time.sleep(1)

    # Get all Sacred Heart team options (just their names)
    options = driver.find_elements(By.CSS_SELECTOR, "div[class*='option']")
    team_names = []
    for option in options:
        try:
            team_name = option.text.strip()
            team_names.append(team_name)
        except Exception:
            continue
    # Click away to close dropdown
    input_elem.send_keys('\ue00c')  # ESC key
    time.sleep(0.5)
    return team_names

def select_team_by_name(driver, team_name):
    # Always re-find the correct team selector dropdown and input
    containers = driver.find_elements(By.CSS_SELECTOR, "div.css-2b097c-container")
    target_container = None
    for container in containers:
        try:
            single_value = container.find_element(By.CSS_SELECTOR, "div.css-5mt280-singleValue")
            label = single_value.text.strip()
            if label != "All":
                target_container = container
                break
        except Exception:
            continue
    if not target_container:
        if len(containers) > 1:
            target_container = containers[1]
        else:
            # If not found, reload the page and try again
            driver.get(XPLORER_URL)
            WebDriverWait(driver, 20).until(
                EC.presence_of_element_located((By.CSS_SELECTOR, "div.css-2b097c-container"))
            )
            time.sleep(1)
            # Now try again recursively (should succeed after reload)
            return select_team_by_name(driver, team_name)

    # Open dropdown
    single_value = target_container.find_element(By.CSS_SELECTOR, "div.css-5mt280-singleValue")
    single_value.click()
    time.sleep(0.5)
    input_elem = target_container.find_element(By.CSS_SELECTOR, "input[type='text']")
    input_elem.clear()
    input_elem.send_keys("Sacred Heart College")
    time.sleep(1)
    options = driver.find_elements(By.CSS_SELECTOR, "div[class*='option']")
    found = False
    for option in options:
        if option.text.strip() == team_name:
            option.click()
            found = True
            break
    if not found:
        raise Exception(f"Could not find team option for '{team_name}'")
    time.sleep(1.5)  # Give time for page to reload

def fetch_all_match_urls(driver):
    # Wait for all match links to appear anywhere on the page
    WebDriverWait(driver, 15).until(
        EC.presence_of_element_located((By.CSS_SELECTOR, "a.css-1bztky2"))
    )
    links = driver.find_elements(By.CSS_SELECTOR, "a.css-1bztky2")
    match_urls = []
    for link in links:
        url = link.get_attribute("href")
        if url:
            match_urls.append(url)
    return match_urls

def extract_match_details(driver, match_url):
    driver.get(match_url)
    try:
        WebDriverWait(driver, 10).until(
            EC.presence_of_element_located((By.CSS_SELECTOR, "main.overflow-hidden"))
        )
    except Exception:
        return {"error": "Could not load match page", "match_url": match_url}

    details = {"match_url": match_url}
    try:
        h1 = driver.find_element(By.CSS_SELECTOR, "div[data-comp='rugby-container'] h1 span")
        details["title"] = h1.text
    except Exception:
        details["title"] = ""

    try:
        teams = driver.find_elements(By.CSS_SELECTOR, "div.css-70qvj9[title]")
        if len(teams) == 2:
            details["home_team"] = teams[0].get_attribute("title")
            details["away_team"] = teams[1].get_attribute("title")
        else:
            details["home_team"] = ""
            details["away_team"] = ""
    except Exception:
        details["home_team"] = ""
        details["away_team"] = ""

    try:
        info_items = driver.find_elements(By.CSS_SELECTOR, "ul.css-lo2e9o li")
        for item in info_items:
            label = item.text.split(" ", 1)[0].strip().lower()
            value = item.find_element(By.CSS_SELECTOR, "span.css-hi81q5").text
            if "time" in label:
                details["date_time"] = value
            elif "location" in label:
                details["location"] = value
    except Exception:
        details["date_time"] = ""
        details["location"] = ""

    try:
        home_score = driver.find_element(By.CSS_SELECTOR, "div.css-psm3s1 div.css-70qvj9:nth-child(1) span.css-mdhdec").text
        details["home_score"] = home_score
    except Exception:
        details["home_score"] = ""
    try:
        away_score = driver.find_element(By.CSS_SELECTOR, "div.css-psm3s1 div.css-70qvj9:nth-child(3) span.css-mdhdec").text
        details["away_score"] = away_score
    except Exception:
        details["away_score"] = ""

    return details

def main():
    chrome_options = Options()
    chrome_options.add_argument("--start-maximized")
    # chrome_options.add_argument("--headless")
    driver = webdriver.Chrome(options=chrome_options)

    try:
        driver.get(XPLORER_URL)
        wait = WebDriverWait(driver, 20)
        wait.until(EC.presence_of_element_located((By.CSS_SELECTOR, "div.css-2b097c-container")))
        time.sleep(1)

        # Get all Sacred Heart team names
        team_names = get_all_sacred_heart_team_names(driver)
        print(f"Found {len(team_names)} Sacred Heart teams.")

        all_teams_data = {}

        for idx, team_name in enumerate(team_names):
            print(f"\nSelecting team {idx+1}/{len(team_names)}: {team_name}")
            select_team_by_name(driver, team_name)
            time.sleep(2)

            match_urls = fetch_all_match_urls(driver)
            print(f"  Found {len(match_urls)} matches for {team_name}.")

            team_matches = []
            for m_idx, match_url in enumerate(match_urls):
                print(f"    Fetching match {m_idx+1}/{len(match_urls)}: {match_url}")
                details = extract_match_details(driver, match_url)
                team_matches.append(details)
                time.sleep(1)  # Be polite to the server

            all_teams_data[team_name] = team_matches

        with open("sacred_heart_rugby_fixtures.json", "w", encoding="utf-8") as f:
            json.dump(all_teams_data, f, ensure_ascii=False, indent=2)

        print(f"\nSaved all Sacred Heart teams' matches to sacred_heart_rugby_fixtures.json.")

    finally:
        driver.quit()

if __name__ == "__main__":
    main()
import requests
import json
from datetime import datetime, timedelta
import os
import time

# --- Configuration ---
DATA_DIR = "api_data"
METADATA_FILENAME = os.path.join(DATA_DIR, 'collegesport_competition_api_data.json')
FIXTURE_DATES_FILENAME = os.path.join(DATA_DIR, 'fixture_dates_data.json')
AVAILABLE_PHASES_FILENAME = os.path.join(DATA_DIR, 'available_phases_data.json')
API_URL_METADATA = "https://www.collegesport.co.nz/api/v2/competition/widget/metadata/"
API_URL_FIXTURE_DATES = "https://www.collegesport.co.nz/api/v2/competition/widget/fixture/Dates"
API_URL_AVAILABLE_PHASES = "https://www.collegesport.co.nz/api/v2/competition/widget/standings/availablePhases"
API_URL_STANDINGS = "https://www.collegesport.co.nz/api/v2/competition/widget/standings/Phase"

# Standard headers to mimic a browser
HEADERS = {
    'Content-Type': 'application/json',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36',
    'Origin': 'https://www.collegesport.co.nz',
    'Referer': 'https://www.collegesport.co.nz/draws-results',
}

# --- Functions ---

def fetch_competition_metadata():
    """
    Fetches the initial competition metadata from the API.
    """
    payload = [
        "10362", "10180", "10181", "10182", "10183", "10184", "10113", 
        "10114", "10115", "10116", "10286", "10288", "10394", "10395", 
        "10396", "10401", "10402", "10403", "10045", "10033", "10034", 
        "10041", "11769", "11109", "11110", "11226", "11227", "10197", 
        "10333", "10334", "10335", "10336", "10337", "10340", "10202", 
        "10203", "10204", "10205", "10206", "10821", "9982", "9983", 
        "9995", "9996", "9974", "9975", "9976", "9977", "9978", "9979", 
        "9980", "9981", "10017", "10046", "10047", "10005", "10006", 
        "10124", "10125", "10126", "10292", "10296", "11261", "10121", 
        "10025", "10026", "10035", "10147", "10148", "10341", "10342", 
        "10343", "10137", "10138", "10185", "10186", "10140", "10141", 
        "10190", "10191", "10207", "10208", "10209", "10200", "10257", 
        "10192", "10193", "10194", "10195", "10196", "10305"
    ]
    
    try:
        print("Fetching competition metadata from the API...")
        response = requests.post(API_URL_METADATA, headers=HEADERS, json=payload)
        response.raise_for_status()
        data = response.json()
        print("Successfully fetched competition metadata.")
        with open(METADATA_FILENAME, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=4)
        print(f"Metadata saved to '{METADATA_FILENAME}'")
        return data
    except requests.exceptions.RequestException as e:
        print(f"An error occurred while fetching metadata: {e}")
    return None

def fetch_fixture_dates(comp_ids=None, org_ids=None, grade_ids=None, from_date=None, to_date=None, output_filename=FIXTURE_DATES_FILENAME):
    """
    Fetches fixture dates from the API with a customizable payload.
    """
    if comp_ids is None: comp_ids = []
    if org_ids is None: org_ids = []
    if grade_ids is None: grade_ids = []
    if from_date is None: from_date = datetime.now().strftime('%Y-%m-%d')
    if to_date is None: to_date = (datetime.now() + timedelta(days=20)).strftime('%Y-%m-%d')

    payload = {"CompIds": comp_ids, "OrgIds": org_ids, "GradeIds": grade_ids, "From": f"{from_date}T00:00:00", "To": f"{to_date}T23:59:00"}
    
    print("\nSending request to fetch fixture dates...")
    try:
        response = requests.post(API_URL_FIXTURE_DATES, headers=HEADERS, json=payload)
        response.raise_for_status()
        fixture_data = response.json()
        print("Success! Fixture data received.")
        with open(output_filename, 'w', encoding='utf-8') as f:
            json.dump(fixture_data, f, ensure_ascii=False, indent=4)
        print(f"Fixture data saved to '{output_filename}'")
        return fixture_data
    except requests.exceptions.RequestException as e:
        print(f"An error occurred fetching fixture dates: {e}")
    return None

def fetch_available_phases(comp_ids=None, output_filename=AVAILABLE_PHASES_FILENAME):
    """
    Fetches the available standings phases for a given list of competition IDs.
    """
    if comp_ids is None: comp_ids = []
    payload = {"CompIds": comp_ids}

    print("\nSending request to fetch available phases...")
    try:
        response = requests.post(API_URL_AVAILABLE_PHASES, headers=HEADERS, json=payload)
        response.raise_for_status()
        phases_data = response.json()
        print("Success! Available phases data received.")
        with open(output_filename, 'w', encoding='utf-8') as f:
            json.dump(phases_data, f, ensure_ascii=False, indent=4)
        print(f"Phases data saved to '{output_filename}'")
        return phases_data
    except requests.exceptions.RequestException as e:
        print(f"An error occurred fetching available phases: {e}")
    return None

def fetch_standings_by_phase(grade_id, phase_id):
    """
    Fetches standings data for a single grade and phase.
    """
    payload = {"GradeId": grade_id, "PhaseId": phase_id}
    output_filename = os.path.join(DATA_DIR, f"standings_grade_{grade_id}_phase_{phase_id}.json")
    
    print(f"\nFetching standings for Grade ID: {grade_id}, Phase ID: {phase_id}")
    try:
        response = requests.post(API_URL_STANDINGS, headers=HEADERS, json=payload)
        response.raise_for_status()
        standings_data = response.json()
        
        with open(output_filename, 'w', encoding='utf-8') as f:
            json.dump(standings_data, f, ensure_ascii=False, indent=4)
        print(f"-> Successfully saved to '{output_filename}'")
        return standings_data
    except requests.exceptions.RequestException as e:
        print(f"-> Failed to fetch standings for Grade {grade_id}, Phase {phase_id}: {e}")
    return None

def fetch_all_standings(competition_data, phases_data):
    """
    Iterates through all available phases and fetches standings for each.
    
    Args:
        competition_data (dict): The data from fetch_competition_metadata.
        phases_data (dict): The data from fetch_available_phases.
    """
    print("\n" + "="*50)
    print("Fetching ALL Standings for Available Grade/Phase Combinations")
    print("="*50)
    
    # Calculate the total number of requests to be made for progress tracking
    total_combinations = sum(len(phases) * len(competition_data.get('GradesPerComp', {}).get(comp_id_str, [])) for comp_id_str, phases in phases_data.items())
    print(f"Found approximately {total_combinations} combinations to fetch.")

    fetch_count = 0
    for comp_id_str, phases in phases_data.items():
        if not phases:
            continue

        grades_for_comp = competition_data.get('GradesPerComp', {}).get(comp_id_str)
        if not grades_for_comp:
            continue
            
        for grade in grades_for_comp:
            for phase in phases:
                # Add a small delay to be respectful to the server
                time.sleep(0.2) 
                
                fetch_standings_by_phase(grade['Id'], phase['Id'])
                fetch_count += 1
                print(f"--- Progress: {fetch_count} / {total_combinations} ---")

if __name__ == "__main__":
    # Ensure the data directory exists
    os.makedirs(DATA_DIR, exist_ok=True)

    # 1. Fetch the initial metadata from the API
    competition_data = fetch_competition_metadata()

    if competition_data:
        # 2. Extract all competition IDs
        all_comp_ids = [comp['Id'] for comp in competition_data.get('Competitions', [])]
        
        # 3. Get available phases for all competitions
        phases_data = fetch_available_phases(comp_ids=all_comp_ids)

        # 4. Fetch all standings for all available combinations
        if phases_data:
            fetch_all_standings(competition_data, phases_data)

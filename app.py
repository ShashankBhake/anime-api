import os
import re
import json
import subprocess
import requests
from flask import Flask, request, jsonify
from flask_cors import CORS
from dotenv import load_dotenv
from pymongo import MongoClient
from rapidfuzz import fuzz

app = Flask(__name__)
CORS(app)  # Enable Cross-Origin Resource Sharing for all routes

# load .env and initialize MongoDB
load_dotenv()
MONGODB_URI = os.getenv('MONGODB_URI')
if not MONGODB_URI:
    raise RuntimeError('MONGODB_URI not set in environment')
client = MongoClient(MONGODB_URI)
# use 'anime_api' database (or default from URI)
db = client.get_database('anime_api')
id_collection = db['id_map']

def normalize_title(title):
    """
    Normalize the title by:
    - Lowercasing
    - Removing non-alphanumeric characters except spaces
    - Removing leading zeros from numbers
    - Stripping extra spaces
    """
    # Remove leading zeros from numbers (e.g., "09" -> "9")
    title = re.sub(r'\b0+(\d+)\b', r'\1', title)
    # Remove punctuation except spaces
    title = re.sub(r'[^\w\s]', '', title)
    # Lowercase and trim
    title = title.lower().strip()
    # Collapse multiple spaces
    title = re.sub(r'\s+', ' ', title)
    return title

def combined_similarity(title1, title2):
    t1 = normalize_title(title1)
    t2 = normalize_title(title2)
    base = fuzz.ratio(t1, t2)
    sort_r = fuzz.token_sort_ratio(t1, t2)
    set_r  = fuzz.token_set_ratio(t1, t2)
    part_r = fuzz.partial_ratio(t1, t2)
    w_ratio = fuzz.WRatio(t1, t2)
    best = max(sort_r, set_r, part_r, w_ratio)
    return best / 100.0

def get_mal_id(anime_title):
    """
    Use the Jikan API to search for the anime by title and return the exact
    MyAnimeList (MAL) id if found, using combined_similarity for matching.
    """
    search_url = f"https://api.jikan.moe/v4/anime?q={anime_title}"
    print(f"[INFO] Searching MAL id for title: {anime_title}")
    try:
        response = requests.get(search_url)
        response.raise_for_status()
        data = response.json()
        if "data" in data:
            best_id = None
            best_score = 0.0
            for anime in data["data"]:
                score1 = combined_similarity(anime_title, anime["title_english"] or "")
                score2 = combined_similarity(anime["title"] or "", anime_title)
                score = max(score1, score2)
                # print(f"[DEBUG] Comparing '{anime_title}' with '{anime['title']}' - Score: {score}")
                if score > best_score:
                    best_score = score
                    best_id = anime["mal_id"]
            print(f"[INFO] Best match for '{anime_title}' is MAL id {best_id} with score {best_score:.2f}")
            if best_score > 0.85:  # threshold for a good match
                return best_id
            else:
                return None
        else:
            print("[WARN] No data found from Jikan API for title:", anime_title)
    except Exception as e:
        print(f"[ERROR] Failed to get MAL id: {e}")
    return None

def init():
    """
    Initialize the environment by ensuring that anime.sh is executable.
    """
    anime_sh_path = os.path.join(os.getcwd(), "anime.sh")
    if os.path.isfile(anime_sh_path):
        try:
            os.chmod(anime_sh_path, 0o755)
            print("[INFO] anime.sh is now executable.")
        except Exception as e:
            print(f"[ERROR] Failed to set anime.sh as executable: {e}")
    else:
        print("[ERROR] anime.sh not found in the current directory.")

# removed in-memory id_map; using MongoDB collection instead

def get_orig_id(mal_id):
    entry = id_collection.find_one({'mal_id': int(mal_id)})
    return entry['orig_id'] if entry else None

def save_mapping(mal_id, orig_id):
    # store mapping by orig_id, mal_id may be None
    id_collection.update_one({'orig_id': orig_id}, {'$set': {'mal_id': mal_id}}, upsert=True)

@app.route('/search', methods=['GET'])
def search():
    query = request.args.get('query', '')
    try:
        output = subprocess.check_output(['./anime.sh', '/search', f'query={query}'])
        lines = output.decode('utf-8').strip().splitlines()
        result = []
        for line in lines:
            parts = line.split("\t")
            if len(parts) != 3:
                continue
            orig_id, title, episodes = parts
            # check existing mapping by internal id
            mapping = id_collection.find_one({'orig_id': orig_id})
            if mapping is not None:
                mal_id = mapping.get('mal_id')  # may be None
            else:
                mal_id = get_mal_id(title)
                save_mapping(mal_id, orig_id)
            use_id = mal_id
            result.append({
                "id": use_id,
                "title": title,
                "episodes": int(episodes)
            })
        return jsonify(result)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/episodes/<mal_id>', methods=['GET'])
def episodes(mal_id):
    # lookup internal anime.sh ID from MongoDB
    orig_id = get_orig_id(mal_id)
    if not orig_id:
        return jsonify({"error": "MAL id not found"}), 404
    try:
        output = subprocess.check_output(['./anime.sh', f'/episodes/{orig_id}'])
        data = json.loads(output.decode('utf-8'))
        return jsonify(data)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/episode_url', methods=['GET'])
def episode_url():
    mal_id = request.args.get('show_id', '')
    orig_id = get_orig_id(mal_id)
    if not orig_id:
        return jsonify({"error": "MAL id not found"}), 404
    ep_no = request.args.get('ep_no', '')
    quality = request.args.get('quality', 'best')
    params = f"show_id={orig_id}&ep_no={ep_no}&quality={quality}"
    try:
        output = subprocess.check_output(['./anime.sh', '/episode_url', params])
        data = json.loads(output.decode('utf-8'))
        return jsonify(data)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/', methods=['GET'])
def index():
    return {
        "title": "Anime API",
        "status": "running",
        "help": "https://github.com/shashankbhake/anime-api",
        "available_endpoints": [
            "/search?query=<query>",
            "/episodes/<show_id>",
            "/episode_url?show_id=<show_id>&ep_no=<ep_no>&quality=<quality>"
        ]
    }

if __name__ == '__main__':
    init()
    # Use the PORT environment variable if provided, default to 5000
    port = int(os.environ.get("PORT", 5678))
    app.run(host='0.0.0.0', port=port, debug=True)

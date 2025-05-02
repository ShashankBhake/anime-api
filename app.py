import os
import re
import json
import subprocess
import requests
from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)  # Enable Cross-Origin Resource Sharing for all routes

def sanitize_string(s):
    """
    Lowercase the string and remove non-alphanumeric characters.
    """
    return re.sub(r'[^a-zA-Z0-9]', '', s).lower()

def get_mal_id(anime_title):
    """
    Use the Jikan API to search for the anime by title and return the exact
    MyAnimeList (MAL) id if found.
    """
    search_url = f"https://api.jikan.moe/v4/anime?q={anime_title}"
    try:
        response = requests.get(search_url)
        response.raise_for_status()
        data = response.json()
        if "data" in data:
            for anime in data["data"]:
                if sanitize_string(anime_title) == sanitize_string(anime["title"]):
                    return anime["mal_id"]
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

# map MAL IDs to internal anime.sh IDs
id_map = {}

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
            mal_id = get_mal_id(title)
            # map and use MAL id
            if mal_id:
                id_map[str(mal_id)] = orig_id
                use_id = mal_id
            else:
                use_id = None
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
    # lookup internal ID
    orig_id = id_map.get(mal_id)
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
    orig_id = id_map.get(mal_id)
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
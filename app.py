from flask import Flask, request, jsonify
from flask_cors import CORS
import subprocess
import json
import os
import re

app = Flask(__name__)
CORS(app)  # Enable Cross-Origin Resource Sharing for all routes

def remove_ansi_codes(s):
    """
    Remove ANSI escape sequences from a string.
    """
    ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
    return ansi_escape.sub('', s)

def clean_output(output):
    """
    Decode the output, remove ANSI escape codes and any remaining
    control characters, then strip leading/trailing whitespace.
    """
    # Decode with error replacement
    decoded = output.decode('utf-8', errors='replace')
    # First remove ANSI sequences
    no_ansi = remove_ansi_codes(decoded)
    # Remove other control characters (except newline and tab if desired)
    cleaned = re.sub(r'[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F]', '', no_ansi).strip()
    return cleaned

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

@app.route('/search', methods=['GET'])
def search():
    query = request.args.get('query', '')
    try:
        output = subprocess.check_output(['./anime.sh', '/search', f'query={query}'])
        cleaned_output = clean_output(output)
        data = json.loads(cleaned_output)
        return jsonify(data)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/episodes/<show_id>', methods=['GET'])
def episodes(show_id):
    try:
        output = subprocess.check_output(['./anime.sh', f'/episodes/{show_id}'])
        cleaned_output = clean_output(output)
        data = json.loads(cleaned_output)
        return jsonify(data)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/episode_url', methods=['GET'])
def episode_url():
    show_id = request.args.get('show_id', '')
    ep_no = request.args.get('ep_no', '')
    quality = request.args.get('quality', 'best')
    params = f"show_id={show_id}&ep_no={ep_no}&quality={quality}"
    try:
        output = subprocess.check_output(['./anime.sh', '/episode_url', params])
        cleaned_output = clean_output(output)
        data = json.loads(cleaned_output)
        return jsonify(data)
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    
@app.route('/')
def index():
    return "API is running"

if __name__ == '__main__':
    init()
    # Use the PORT environment variable if provided, default to 5000
    port = int(os.environ.get("PORT", 5000))
    app.run(host='0.0.0.0', port=port, debug=True)
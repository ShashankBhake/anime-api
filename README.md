# Anime API Documentation

## Overview

Search for anime titles, retrieve episode lists, and get playback URLs for specific episodes.

## Endpoints

### 1. `/search`

-   **Method**: GET
-   **Description**: Search for anime titles.
-   **Request**:
    ```
    GET https://allanime-api.up.railway.app/search?query=death%20note
    ```
-   **Response**:
    ```json
    [
        {
            "episodes": 1,
            "id": "XuYhavYftLYbaqizA",
            "title": "Death Note Rewrite: The Visualizing God"
        },
        {
            "episodes": 1,
            "id": "4faC8vAweqoestJgw",
            "title": "Death Note: Rewrite"
        },
        {
            "episodes": 37,
            "id": "RezHft5pjutwWcE3B",
            "title": "Death Note"
        }
    ]
    ```

### 2. `/episodes/<show_id>`

-   **Method**: GET
-   **Description**: Retrieve a list of episode numbers for a given anime.
-   **Request**:
    ```
    GET https://allanime-api.up.railway.app/episodes/RezHft5pjutwWcE3B
    ```
-   **Response**:
    ```json
    [1, 2, 3, ... 37]
    ```

### 3. `/episode_url`

-   **Method**: GET
-   **Description**: Retrieve the playback URL for a specific anime episode.
-   **Request**:
    ```
    GET https://allanime-api.up.railway.app/episode_url?show_id=RezHft5pjutwWcE3B&ep_no=1&quality=best
    ```
-   **Response**:
    ```json
    {
        "episode_url": "https://video.wixstatic.com/video/16a5b8_97c31b8a4dcf484d8504892efad683db/1080p/mp4/file.mp4"
    }
    ```

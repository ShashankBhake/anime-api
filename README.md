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
            "id": null,
            "title": "Death Note Rewrite: The Visualizing God"
        },
        {
            "episodes": 1,
            "id": 2994,
            "title": "Death Note: Rewrite"
        },
        {
            "episodes": 37,
            "id": 1535,
            "title": "Death Note"
        }
    ]
    ```

### 2. `/episodes/<show_id>`

-   **Method**: GET
-   **Description**: Retrieve a list of episode numbers for a given anime.
-   **Request**:
    ```
    GET https://allanime-api.up.railway.app/episodes/1535
    ```
-   **Response**:
    ```json
    [
        1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37
    ]
    ```

### 3. `/episode_url`

-   **Method**: GET
-   **Description**: Retrieve the playback URL for a specific anime episode.
-   **Request**:
    ```
    GET https://allanime-api.up.railway.app/episode_url?show_id=1535&ep_no=1&quality=best
    ```
-   **Response**:
    ```json
    {
        "episode_url": "https://myanime.sharepoint.com/sites/anime/_layouts/15/download.aspx?share=EdX2QuABJpNIhTzl8_M49t4By_4PIuMwLnO3HVAlXAwi4Q"
    }
    ```

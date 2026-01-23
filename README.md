# Anime API Documentation

## Overview

Search for anime titles, retrieve episode lists, and get playback URLs for specific episodes. Supports both **subbed** and **dubbed** versions.

## Endpoints

### 1. `/search`

- **Method:** GET
- **Description:** Search for anime titles. Returns both sub and dub episode counts.

**Request:**

```http
GET /search?query=death%20note
```

**Response:**

```json
[
    {
        "id": null,
        "title": "Death Note Rewrite: The Visualizing God",
        "episodes_sub": 1,
        "episodes_dub": 0
    },
    {
        "id": 2994,
        "title": "Death Note: Rewrite",
        "episodes_sub": 1,
        "episodes_dub": 1
    },
    {
        "id": 1535,
        "title": "Death Note",
        "episodes_sub": 37,
        "episodes_dub": 37
    }
]
```

---

### 2. `/anime/<mal_id>`

- **Method:** GET
- **Description:** Retrieve detailed information about a specific anime by its MyAnimeList ID. Returns cached metadata (including thumbnail, synopsis, score, etc.) and the calculated episode count (sub).

**Request:**

```http
GET /anime/21
```

**Response:**

```json
{
    "mal_id": 21,
    "title": "One Piece",
    "title_english": "One Piece",
    "thumbnail_url": "https://cdn.myanimelist.net/images/anime/1244/138851l.jpg",
    "synopsis": "Barely surviving in a barrel after passing through a terrible whirlpool at sea...",
    "score": 8.73,
    "genres": [
        { "mal_id": 1, "type": "anime", "name": "Action", "url": "..." },
        { "mal_id": 2, "type": "anime", "name": "Adventure", "url": "..." }
    ],
    "episode_count": 1092,
    "status": "Currently Airing",
    "year": 1999
}
```

---

### 3. `/episodes/<show_id>`

- **Method:** GET
- **Description:** Retrieve a list of episode numbers for a given anime.

**Parameters:**

| Parameter | Required | Default | Description                                                     |
| --------- | -------- | ------- | --------------------------------------------------------------- |
| `mode`    | No       | `sub`   | `sub` or `dub` - specifies which version's episodes to retrieve |

**Request:**

```http
GET /episodes/1535
GET /episodes/1535?mode=dub
```

**Response:**

```json
{
    "mode": "sub",
    "episodes": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
}
```

> **Note:** Sub and dub versions may have different episode counts. For example, an anime might have 24 subbed episodes but only 12 dubbed episodes if the dub is still in progress.

---

### 4. `/episode_url`

- **Method:** GET
- **Description:** Retrieve the playback URL for a specific anime episode.

**Parameters:**

| Parameter | Required | Default | Description                                        |
| --------- | -------- | ------- | -------------------------------------------------- |
| `show_id` | Yes      | -       | The MAL ID of the anime                            |
| `ep_no`   | Yes      | -       | Episode number                                     |
| `quality` | No       | `best`  | Video quality                                      |
| `mode`    | No       | `sub`   | `sub` or `dub` - specifies which version to stream |

**Request:**

```http
GET /episode_url?show_id=1535&ep_no=1&quality=best
GET /episode_url?show_id=1535&ep_no=1&quality=best&mode=dub
```

**Response:**

```json
{
    "episode_url": "https://example.com/stream/...",
    "mode": "dub"
}
```

---

## Sub vs Dub

| Mode  | Description                                    |
| ----- | ---------------------------------------------- |
| `sub` | Original Japanese audio with English subtitles |
| `dub` | English voice-over audio                       |

The `mode` parameter defaults to `sub` if not specified. Always check `episodes_sub` and `episodes_dub` counts from the search results before requesting a specific episode, as dub releases often lag behind sub releases.

# Nitter JSON API Documentation

This document describes all available JSON API endpoints in the Nitter application.

## Health Check

### GET /api/health

Simple health check endpoint to verify the API is running.

**Response:**
| Field    | Type   | Description |
|----------|--------|-------------|
| message  | string | Status message ("OK") |

## Lists

### GET /api/@name/lists/@slug

Get information about a specific list.

**Parameters:**
| Parameter | Type   | Description                    |
|-----------|--------|--------------------------------|
| name      | string | Username of the list owner     |
| slug      | string | URL-friendly name of the list  |

**Response:**
| Field       | Type   | Description                    |
|-------------|--------|--------------------------------|
| id          | string | Unique identifier of the list  |
| name        | string | Display name of the list       |
| userId      | string | ID of the list owner           |
| username    | string | Username of the list owner     |
| description | string | Description of the list        |
| members     | int    | Number of members in the list  |
| banner      | string | Banner image URL               |

### GET /api/i/lists/@id

Get information about a list by its ID.

**Parameters:**
| Parameter | Type   | Description                    |
|-----------|--------|--------------------------------|
| id        | string | Unique identifier of the list  |

**Response:** Same as above

### GET /api/i/lists/@id/timeline

Get tweets from a specific list.

**Parameters:**
| Parameter | Type   | Description                    |
|-----------|--------|--------------------------------|
| id        | string | Unique identifier of the list  |

**Response:**
| Field      | Type   | Description                    |
|------------|--------|--------------------------------|
| pagination | object | Pagination information         |
| timeline   | array  | Array of tweets                |

### GET /api/i/lists/@id/members

Get members of a specific list.

**Parameters:**
| Parameter | Type   | Description                    |
|-----------|--------|--------------------------------|
| id        | string | Unique identifier of the list  |

**Response:**
| Field      | Type   | Description                    |
|------------|--------|--------------------------------|
| pagination | object | Pagination information         |
| users      | array  | Array of user objects          |

## Search

### GET /api/search

Search for tweets or users based on a query.

**Parameters:**
| Parameter | Type   | Description                    |
|-----------|--------|--------------------------------|
| q         | string | Search query (max 500 chars)   |

**Response:**
| Field      | Type   | Description                    |
|------------|--------|--------------------------------|
| pagination | object | Pagination information         |
| timeline   | array  | Array of tweets (for tweet search) |
| users      | array  | Array of users (for user search) |

**Notes:**
- The search type is determined by the query format
- For user search, if the query contains a comma, it will redirect to the user profile page
- Returns error if search input is too long (>500 characters)
- Returns error for invalid search types

### GET /api/hashtag/@hash

Redirect to search results for a specific hashtag.

**Parameters:**
| Parameter | Type   | Description                    |
|-----------|--------|--------------------------------|
| hash      | string | Hashtag to search for          |

**Response:**
Redirects to `/search?q=#hashtag`

## User Profile

### GET /api/@name/profile

Get detailed profile information for a user.

**Parameters:**
| Parameter | Type   | Description                    |
|-----------|--------|--------------------------------|
| name      | string | Username to look up            |

**Response:**
| Field      | Type   | Description                    |
|------------|--------|--------------------------------|
| user       | object | User information               |
| photoRail  | array  | User's media gallery           |
| pinned     | object | User's pinned tweet (if any)   |

### GET /api/@name/?@tab

Get user's timeline with optional tab filter.

**Parameters:**
| Parameter | Type   | Description                    |
|-----------|--------|--------------------------------|
| name      | string | Username to look up            |
| tab       | string | Filter type (with_replies/media/search) |

**Response:**
| Field      | Type   | Description                    |
|------------|--------|--------------------------------|
| pagination | object | Pagination information         |
| timeline   | array  | Array of tweets                |

### GET /api/i/user/@user_id

Get username for a user ID.

**Parameters:**
| Parameter | Type   | Description                    |
|-----------|--------|--------------------------------|
| user_id   | string | User ID to look up             |

**Response:**
| Field    | Type   | Description                    |
|----------|--------|--------------------------------|
| username | string | Username associated with the ID |

## Data Models

### User Object
| Field         | Type   | Description                    |
|---------------|--------|--------------------------------|
| id            | string | User's unique identifier       |
| username      | string | User's username                |
| fullname      | string | User's display name            |
| location      | string | User's location                |
| website       | string | User's website URL             |
| bio           | string | User's biography               |
| userPic       | string | Profile picture URL            |
| banner        | string | Banner image URL               |
| pinnedTweet   | string | ID of pinned tweet             |
| following     | int    | Number of accounts following   |
| followers     | int    | Number of followers            |
| tweets        | int    | Number of tweets               |
| likes         | int    | Number of likes                |
| media         | int    | Number of media items          |
| verifiedType  | string | Verification status            |
| protected     | bool   | Account protection status      |
| suspended     | bool   | Account suspension status      |
| joinDate      | int    | Account creation timestamp     |

### Tweet Object
| Field         | Type   | Description                    |
|---------------|--------|--------------------------------|
| id            | string | Tweet's unique identifier      |
| threadId      | string | ID of the thread               |
| replyId       | string | ID of the replied tweet        |
| user          | object | User information               |
| text          | string | Tweet content                  |
| time          | int    | Tweet timestamp                |
| reply         | bool   | Is a reply                     |
| pinned        | bool   | Is pinned                      |
| hasThread     | bool   | Has thread                     |
| available     | bool   | Is available                   |
| tombstone     | bool   | Is deleted                     |
| location      | string | Location information           |
| source        | string | Tweet source                   |
| stats         | object | Engagement statistics          |
| retweet       | object | Retweeted tweet (if any)       |
| attribution   | object | Attribution information        |
| quote         | object | Quoted tweet (if any)          |
| poll          | object | Poll information (if any)      |
| gif           | object | GIF information (if any)       |
| video         | object | Video information (if any)     |
| photos        | array  | Photo URLs (if any)            |

### Pagination Object
| Field      | Type   | Description                    |
|------------|--------|--------------------------------|
| beginning  | bool   | Is first page                  |
| top        | string | Top cursor                     |
| bottom     | string | Bottom cursor                  |
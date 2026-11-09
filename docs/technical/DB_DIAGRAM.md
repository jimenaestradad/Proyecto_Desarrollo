# Nori — Database Diagram

Logical entity-relationship view of the Firestore database on project `nori-pet`. Firestore is
a document database, so there are no foreign-key constraints: every "relationship" below is
either **containment** (a subcollection under `/users/{uid}`) or a **stored id** the app
resolves itself. The field-by-field description, write rules and rationale are in
[BACKEND.md](BACKEND.md) ("Firestore schema") and [firestore.rules](../../firestore.rules).

```mermaid
erDiagram
    USERS ||--o{ HABITS : "has (subcollection)"
    USERS ||--o{ HABIT_LOGS : "has (subcollection)"
    HABITS ||--o{ HABIT_LOGS : "one log per habit per day"
    USERS ||--|| PET : "has (pet/main)"
    USERS ||--|| INVENTORY : "has (inventory/main)"
    USERS ||--o{ BUCKET_LIST_ITEMS : "has (subcollection)"
    USERS ||--o{ NOTIFICATIONS : "has (subcollection)"
    USERS ||--|| NOTIFICATION_STATE : "has (notificationState/main)"
    USERS ||--|| USERNAMES : "claims (global index)"

    USERS {
        string uid PK "doc id = Firebase Auth uid"
        string name
        string username "display casing"
        string email
        string avatarUrl "null today, photos are session-only"
        timestamp createdAt
        int level "Cloud Function only"
        int totalXp "Cloud Function only"
        int xpIntoLevel "Cloud Function only"
        int xpForNextLevel "Cloud Function only"
        int coins "Cloud Function only"
        bool vacationModeEnabled
        array vacationRanges "start, end (end null = open)"
        array habitCategories "user-editable strings"
        timestamp firstHabitCompletedAt "null until first claim"
    }

    HABITS {
        string habitId PK
        string name
        string subtitle "category text"
        string iconKey "registry key"
        string colorKey "palette key"
        int xpReward
        int coinReward
        string repeat "enum name"
        string type "enum name"
        string difficulty "enum name"
        number targetValue
        string unit
        number minThreshold
        number quickLogAmount
        number adaptiveMultiplier "Cloud Function computed"
        array customDays
        bool allowVacationFreeze
        timestamp startDate
        timestamp endDate
        int order
        bool archived
        array archivedRanges "start, end dayKeys"
        timestamp createdAt
    }

    HABIT_LOGS {
        string logId PK "dayKey_habitId"
        string habitId FK
        string dayKey "yyyy-mm-dd, device-local"
        timestamp date "local midnight"
        number value
        bool claimed "Cloud Function only"
        int awardedXp "Cloud Function only"
        int awardedCoins "Cloud Function only"
    }

    PET {
        string petId PK "main (one doc today)"
        string name
        int hunger
        int hygiene
        int happiness
        timestamp lastDecayAt
        string stage "Cloud Function only"
        int evolutionLevelThreshold "Cloud Function only"
    }

    INVENTORY {
        string inventoryId PK "main"
        map careItemCounts "item id to count, client can only decrease"
        array ownedAccessoryIds "client can never add"
        string equippedAccessoryId "must be owned, or null"
    }

    BUCKET_LIST_ITEMS {
        string itemId PK
        string title
        string description
        string iconKey
        string colorKey
        int xpReward "capped 500 server-side"
        int coinReward "capped 250 server-side"
        bool isCompleted "Cloud Function only"
        timestamp completedAt "Cloud Function only"
        int awardedXp "Cloud Function only"
        int awardedCoins "Cloud Function only"
    }

    NOTIFICATIONS {
        string notificationId PK
        string kind "levelUp, petEvolved, gift, petCare, achievement, streak"
        string message
        timestamp createdAt
        bool isRead
    }

    NOTIFICATION_STATE {
        string stateId PK "main"
        array achievementIds "client"
        int streakMilestone "client"
        string streakMilestoneDay "client"
        int level "Cloud Function only"
        bool petEvolved "Cloud Function only"
        timestamp petCareAt "Cloud Function only"
    }

    USERNAMES {
        string usernameLower PK "lowercased username"
        string uid FK
        string username "display casing"
        timestamp createdAt
    }
```

## Reading it

- **Everything except `USERNAMES` lives under `/users/{uid}`.** `HABITS`, `HABIT_LOGS`, `PET`,
  `INVENTORY`, `BUCKET_LIST_ITEMS`, `NOTIFICATIONS` and `NOTIFICATION_STATE` are subcollections
  of one user. `USERNAMES` is the only top-level collection besides `users`; it exists so
  username uniqueness can be enforced across users.
- **`HABIT_LOGS` is flat, not nested under a habit.** A log's id is `{dayKey}_{habitId}`, so
  there is at most one log per habit per day, and a month of history for every habit comes from
  one range query on `date`.
- **`PET`, `INVENTORY` and `NOTIFICATION_STATE` are one-document collections** (`main`), so they
  are shown as 1:1 with the user. The pet is a collection so that more pets can be added later
  without reshaping the data.
- **Not stored, on purpose:** the current streak and achievement unlock state are computed from
  the habit logs and the other entities. Achievement and care-item/accessory definitions are
  bundled app constants; `INVENTORY` stores only their string ids.
- **"Cloud Function only"** fields are rejected by the security rules on client writes. Only the
  Admin SDK (the Cloud Functions) can change them.
- **Not in the database:** the social tab (mock data only) and anything in Firebase Auth itself
  (password, providers), which lives in the Auth service rather than Firestore.

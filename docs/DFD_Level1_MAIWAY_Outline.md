# Data Flow Diagram Level 1 – MAIWAY (Outline)

Based on the **Context Diagram (Figure 18)** and the MAIWAY codebase. Use only the three external entities from the context diagram; processes and data stores are derived from the app/backend.

---

## 1. External Entities (from Context Diagram only)

| Symbol | Entity    | Role |
|--------|-----------|------|
| **Commuters** | End users | Send user queries, travel requests, log-in details, reports; receive fare estimates, route suggestions, chatbot responses. |
| **Admin**     | System operator | Send crowd source validation, user reports (review), user details; receive system notifications. |
| **LTFRB**     | Regulator / data provider | Send legalities and policies, fare matrix, route data into MAIWAY. |

---

## 2. Processes (Level 1 – from code and context flows)

Number and label each process as in the example (1.0, 2.0, …).

| #   | Process name              | Brief description (from code) |
|-----|---------------------------|--------------------------------|
| 1.0 | **Account Management**    | Login, signup, password reset, edit profile, change password (Firebase Auth + Firestore `users`). Handles *log in details* from Commuters and *user details* for Admin. |
| 2.0 | **Route & Fare Planning** | Place search (autocomplete/details/reverse), multicriteria routing (fastest/cheapest/convenient), stop search, fare computation. Consumes *Travel requests* from Commuters; uses *route data* and *fare matrix* from LTFRB; outputs *Route suggestions* and *Fare estimates* to Commuters. |
| 3.0 | **Chatbot / Commuter Assistance** | Chat and dynamic suggestions (FAQ-based). Consumes *User queries* from Commuters; outputs *Chatbot responses* to Commuters. |
| 4.0 | **Report Management**     | Commuters submit *Reports*; Admin sends *User Reports* (review) and *crowd source validation*; system sends *System Notifications* to Admin. Uses Firestore reports collection. |
| 5.0 | **Legalities & Fare Information** | Stores and serves *legalities and policies* and *fare matrix* from LTFRB (e.g. fare_matrix_page, legalities_page). Feeds 2.0 and Commuters (view only). |

---

## 3. Data Stores

| Id  | Data store name     | Contents (from code) |
|-----|---------------------|----------------------|
| D1  | **Users**           | Account details (Firestore `users`: profile, role). Used by 1.0 Account Management. |
| D2  | **Route & Fare Data** | Route data, fare matrix, GTFS/routing data (backend + LTFRB inputs). Used by 2.0 Route & Fare Planning. |
| D3  | **Reports**         | User reports (Firestore). Used by 4.0 Report Management. |
| D4  | **Legalities & Policies** | Legalities and policies, fare matrices (LTFRB; PDFs / static content). Used by 5.0 and 2.0. |
| D5  | **FAQ / Chatbot Data** | FAQ and chatbot content. Used by 3.0 Chatbot. |

---

## 4. Data Flows (outline for arrows)

Label arrows as in the example. Only flows that appear in the context diagram or support them are listed.

### 4.1 Commuters ↔ System

- **Commuters → 1.0 Account Management:** Log in details, signup details.
- **1.0 Account Management → Commuters:** Login success, account status.
- **Commuters → 2.0 Route & Fare Planning:** Travel requests (origin, destination, preferences).
- **2.0 Route & Fare Planning → Commuters:** Route suggestions, Fare estimates.
- **Commuters → 3.0 Chatbot:** User queries.
- **3.0 Chatbot → Commuters:** Chatbot responses.
- **Commuters → 4.0 Report Management:** Reports (complaint/report submission).

### 4.2 Admin ↔ System

- **Admin → 1.0 Account Management:** User details (e.g. view/list).
- **1.0 Account Management → Admin:** Account details / user list.
- **Admin → 4.0 Report Management:** User Reports (review), crowd source validation.
- **4.0 Report Management → Admin:** System Notifications, report list/status.

### 4.3 LTFRB → System

- **LTFRB → 5.0 Legalities & Fare Information:** legalities and policies, fare matrix.
- **LTFRB → 2.0 Route & Fare Planning (or D2):** route data (conceptually; can be drawn as LTFRB → D2 if you model LTFRB as updating the store).

### 4.4 Processes ↔ Data Stores

- **1.0 ↔ D1 Users:** Account details (read/write).
- **2.0 ↔ D2 Route & Fare Data:** Route data, fare matrix (read).
- **2.0 ↔ D4 Legalities & Fare Information:** Fare/policy info (read) if you keep D4 separate.
- **3.0 ↔ D5 FAQ / Chatbot Data:** FAQ data (read); admin updates can be shown via Admin → 3.0 or a separate admin process.
- **4.0 ↔ D3 Reports:** Store details, report list, generate report (read/write).
- **5.0 ↔ D4 Legalities & Policies:** Store/retrieve legalities and fare matrices (read; write when LTFRB updates).

---

## 5. How to draw it (like the second picture)

1. **External entities:** Three boxes – Commuters (e.g. left), Admin (e.g. right or left), LTFRB (e.g. bottom).
2. **Processes:** Five rounded rectangles – 1.0 Account Management, 2.0 Route & Fare Planning, 3.0 Chatbot, 4.0 Report Management, 5.0 Legalities & Fare Information.
3. **Data stores:** Five open rectangles – D1 Users, D2 Route & Fare Data, D3 Reports, D4 Legalities & Policies, D5 FAQ / Chatbot Data.
4. **Arrows:** Use the flow labels above; each arrow has a short phrase (e.g. “Travel requests”, “Fare estimates”, “Account details”).
5. **Numbering:** Keep process numbers 1.0–5.0 and data store IDs D1–D5 for clarity.

---

## 6. Optional simplification (4 processes, like the example)

If you want exactly four processes (to mirror the example):

| #   | Process |
|-----|---------|
| 1.0 | Account Management |
| 2.0 | Route & Fare Planning (route + fare + legalities viewing) |
| 3.0 | Chatbot / Commuter Assistance |
| 4.0 | Report Management |

Then treat **Legalities & Fare Information** as part of 2.0 and/or a single data store (e.g. merge D2 and D4 into “Route, Fare & Policy Data”). LTFRB still feeds this store or 2.0.

---

## 7. Code references (for your write-up)

- **Account:** `loginpage.dart`, `signup.dart`, `auth_service.dart`, `edit_profile.dart`, `change_pass.dart`, Firestore `users`.
- **Route & Fare:** `map_screen.dart`, `route_mode_screen.dart`, `routing_service.dart`, `route_processor.dart`, backend `routing/routing.py`, fare matrices.
- **Chatbot:** `chatbot_dialog.dart`, `chatbot_conversation_manager.dart`, backend `chatbot.py`.
- **Reports:** `user_report_page.dart`, `user_report_history_page.dart`, `admin.dart` (reports tab), Firestore reports.
- **Legalities / Fare info:** `legalities_page.dart`, `fare_matrix_page.dart` (LTFRB content).

Use this outline to draw the Level 1 DFD so it stays consistent with your context diagram and the second picture’s style.

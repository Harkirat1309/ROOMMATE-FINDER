# Find Your Roommate – Intelligent Hostel Roommate Matching System

![License](https://img.shields.io/badge/License-Not%20Specified-lightgrey)
![Node.js](https://img.shields.io/badge/Tech-Node.js-orange)

## Project Overview

Find Your Roommate is an intelligent hostel roommate matching platform that helps students find compatible roommates based on lifestyle, habits, and personal preferences. Users can create detailed profiles, specify roommate expectations, receive compatibility-based suggestions, send roommate requests, and confirm pairings through a structured workflow.

## Problem Statement

Students living in hostels often struggle to find compatible roommates. Random roommate allocation can lead to conflicts due to mismatched habits, study schedules, cleanliness standards, and personal preferences. This project addresses those issues by matching students on compatibility factors and streamlining roommate pairing.

## Key Features

- User profile creation with lifestyle and preference details
- Compatibility-based roommate suggestions
- Roommate request and approval workflow
- Live pairing and activity tracking via database procedures and views
- REST API endpoints for user, profile, pairing, and compatibility management
- PDF generation utility for documentation using Puppeteer

## How the Matching System Works

1. Users register and complete a profile with preferences such as food habits, sleep schedule, cleanliness, study habit, social behavior, hobbies, location, and occupation.
2. The system computes compatibility scores using database functions and stored procedures.
3. Users can browse available matches and send pairing requests.
4. Recipients can accept or reject roommate requests.
5. Accepted pairings are stored and tracked in the database, while pending requests are monitored and managed.

## System Architecture

The repository contains a mixed architecture with the following components:

- Root automation utility (`generate_pdf.js`) using Puppeteer for PDF export
- Nested `ROOOMIE/` folder containing the backend Node.js REST API and database scripts
- A live dashboard page for data inspection and monitoring
- SQL scripts for schema, procedures, functions, triggers, views, sample data, and query examples

## Database Design Overview

The database is designed for roommate matching with support for:

- User account management
- Detailed lifestyle and profile data
- Pairings and compatibility scoring
- Activity logging for audit and history
- Views for fast access to available, pending, and accepted pairings

## ER Diagram

An ER diagram illustrates the relationships among users, profiles, pairings, activity logs, sessions, and notifications.

> **ER Diagram:** No local ER diagram image was found in this workspace. Add `docs/er-diagram.png` or an equivalent asset for a visual reference.

## Technologies Used

- Node.js
- Express
- MySQL / MySQL Workbench
- dotenv
- bcryptjs
- cors
- mysql2
- puppeteer
- HTML

## Installation & Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/Harkirat1309/ROOMMATE-FINDER.git
   cd ROOMMATE-FINDER
   ```
2. Install root dependencies:
   ```bash
   npm install
   ```
3. Install backend dependencies inside `ROOOMIE/`:
   ```bash
   cd ROOOMIE
   npm install
   ```
4. Configure database connection in `ROOOMIE/.env` (create from `.env.example` if needed).
5. Load database schema and objects in MySQL Workbench:
   - `ROOOMIE/01_schema.sql`
   - `ROOOMIE/02_procedures.sql`
   - `ROOOMIE/03_functions_triggers.sql`
   - `ROOOMIE/04_views.sql`
   - `ROOOMIE/05_sample_data_and_queries.sql`
6. Start the backend:
   ```bash
   cd ROOOMIE
   npm start
   ```

## Project Structure

```
ROOOMIE/
├── 01_schema.sql
├── 02_procedures.sql
├── 03_functions_triggers.sql
├── 04_views.sql
├── 05_sample_data_and_queries.sql
├── dashboard.html
├── package.json
├── README.md
└── server.js

generate_pdf.js
package.json
package-lock.json
viva_print.html
ROOOMIE_Viva_Preparation.pdf
```

## Screenshots

No screenshot images were available in the workspace. Add visual assets under `assets/` or `docs/` to enhance this section.

## Future Enhancements

- Add user authentication and authorization
- Build a full web/mobile frontend for student matching
- Add roommate chat and notification features
- Enable machine learning-based compatibility predictions
- Add administrator dashboard and hostel room allocation controls

## License

No license file is currently included in this repository. Add a `LICENSE` file to define the project license clearly.

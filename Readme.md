# HospitalD

A distributed healthcare management system designed with a microservices approach to handle patient data, financial flows, and compliance monitoring.

---

## Architecture Overview

The system is split into independent services, integrated with an OPA (Open Policy Agent) policy engine for robust SOC compliance:

1. **Doctor / Data Flow App** (Flask): A simple Python application to manage and track patient data.
2. **Clerk App** (Node.js): A real-time application for handling financial operations and money flow.
3. **Patient App**: A dedicated interface for patients to track their own data and records.
4. **Policy Engine**: Uses Open Policy Agent (OPA) with Rego for system-wide access control and SOC compliance.
5. **Database**: Combines SQL (for structured roles and relations) with MongoDB for flexible, scalable document storage.

---

## Data Models & Relations

```mermaid
erDiagram
    DOCTORS {
        int id pk
        varchar username
        varchar email
        user_role role
        timestamp created_at
    }

    PATIENTS {
        int id pk
        varchar username
        varchar email
        user_role role
        jsonb summary
        int doctor_id fk
        timestamp created_at
    }

    CLERKS {
        int id pk
        varchar username
        varchar email
        int doctor_id fk
        user_role role
        timestamp created_at
    }

    RECIPES {
        int id pk
        int doctor_id fk
        int patient_id fk
        varchar title
        decimal price
        varchar status
        timestamp created_at
    }

    DOCTORS ||--0{ PATIENTS : "manages"
    DOCTORS ||--0{ CLERKS : "manages"
    DOCTORS ||--0{ RECIPES : "issues"
    PATIENTS ||--0{ RECIPES : "holds"
```

---

## Project Structure

```text
.
├── Clerk/                  # Real-time financial & billing operations (Node.js)
│   ├── app.js
│   ├── Dockerfile
│   └── package.json
├── Doctor/                 # Patient data flow management (Flask)
│   ├── main.py
│   ├── Dockerfile
│   └── requirements.txt
├── Models/                 # Database schema and initial data seeds
│   ├── models.sql
│   └── seed.sql
├── Polices/                # Open Policy Agent (OPA) rules
│   └── hospital.rego
├── Test/                   # Policy evaluation testing scripts
│   └── test_hospital_policy.sh
├── docker.compose.yml      # Multi-container local orchestration
├── seed.sh                 # Initialization and seeding entry point
└── Readme.md
```

---

## Open Policy Agent (OPA)

The project includes an OPA engine configuration (`Polices/hospital.rego`) to ensure secure data access and adherence to SOC standards. The policies validate user roles and permissions before allowing read or write actions across the system.

---

## Getting Started

### Prerequisites

- **Docker & Docker Compose**
- **Node.js** & **npm** (for the Clerk service)
- **Python 3.10+** (for the Doctor service)

### Quick Start

1. **Build and run the containers:**

   ```bash
   docker-compose up --build
   ```

2. **Initialize the database:**

   ```bash
   ./seed.sh
   ```

3. **Verify policies:**

   ```bash
   bash Test/test_hospital_policy.sh
   ```

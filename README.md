# dispatch-offer-router
A small Ruby/Sinatra service for managing a simple dispatch workflow:

- Receive a job via API
- Generate an approval link
- Offer the job to drivers in priority order
- Track responses and escalation
- Maintain state in a lightweight SQLite database

This project models a real-world dispatch scenario where work is created externally (e.g. from a spreadsheet, email parser, or webhook), approved by a coordinator, and then offered sequentially to available drivers.

It is intentionally small and readable. The focus is clarity of logic and extensibility rather than over-engineering.

---

## Current Capabilities

- JSON API for job creation
- Clean link-based approval page
- Priority-based driver offer cascade
- Offer timeout handling via a scheduler endpoint
- Webhook endpoint for driver YES/NO responses
- SQLite persistence for jobs, agents, and offers
- Basic test coverage for core workflow

---

## Work In Progress

This service currently uses a “fake” dispatcher that logs outbound messages to the console. 

Future updates will include:

- Real SMS / WhatsApp integration (e.g. Twilio)
- External scheduler integration instead of manual `/tick`
- Optional email approval workflows
- Improved reporting endpoints
- Swappable database backend (e.g. Postgres)

The goal is to keep the workflow engine stable while making inbound and outbound communication layers easy to replace.

---

## Setup

Install dependencies:
bundle install

Copy the environment template:
copy .env.example .env

Initialise the database:
bundle exec ruby db/setup.rb

Seed sample drivers:
bundle exec ruby db/seed.rb

Start the server:
bundle exec ruby app.rb

Health check:
http://localhost:4567/health
Example API Usage

Sync drivers
curl -X POST "http://localhost:4567/agents/sync" -H "content-type: application/json" -d "{\"agents\":[{\"name\":\"Driver One\",\"phone_e164\":\"+447700900001\",\"priority\":1,\"active\":true}]}"
Create a job
curl -X POST "http://localhost:4567/jobs" -H "content-type: application/json" -d "{\"sheet_job_id\":\"VC8Y-3\",\"pickup_date\":\"30/01/2026\",\"pickup_time\":\"14:30\",\"origin\":\"Leeds\",\"destination\":\"Manchester\",\"vehicle_type\":\"Van\"}"

Open the returned approve_url in your browser. Intention is to have this as a link in an approval email

Start offering
curl -X POST "http://localhost:4567/jobs/1/start_offers"
Simulate driver response
curl -X POST "http://localhost:4567/webhooks/driver_response" -H "content-type: application/json" -d "{\"from\":\"+447700900001\",\"job_id\":1,\"response\":\"YES\"}"
Run escalation check
curl -X POST "http://localhost:4567/tick"

The intention is to keep behaviour predictable and easy to test while allowing communication layers (SMS, email, webhooks) to evolve independently.

Testing:

Run:
bundle exec ruby -Itest test/jobs_flow_test.rb

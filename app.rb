require "sinatra"
require "json"
require "dotenv"

Dotenv.load

require_relative "./lib/workflow"

set :bind, "0.0.0.0"
set :port, (ENV["PORT"] || 4567).to_i

BASE_URL = ENV.fetch("BASE_URL", "http://localhost:4567")
TIMEOUT_MINUTES = ENV.fetch("OFFER_TIMEOUT_MINUTES", "30").to_i

WORKFLOW = Workflow.new(base_url: BASE_URL, timeout_minutes: TIMEOUT_MINUTES)

before do
  # Default all API responses to JSON, except for approve page which returns HTML.
  content_type :json
end

get "/health" do
  { status: "ok" }.to_json
end

# --- Agents sync ---
post "/agents/sync" do
  payload = JSON.parse(request.body.read)
  res = WORKFLOW.sync_agents!(payload.fetch("agents"))
  { ok: true, **res }.to_json
end

# --- Create job (returns approval link) ---
post "/jobs" do
  payload = JSON.parse(request.body.read)
  res = WORKFLOW.create_job!(payload)
  status(res[:message] == "already_exists" ? 200 : 201)
  res.to_json
end

# --- Fetch job ---
get "/jobs/:id" do
  require_relative "./lib/db"
  job = DB[:jobs].where(id: params[:id].to_i).first
  halt 404, { error: "not_found" }.to_json unless job
  job.to_json
end

# --- Approve job ---
get "/approve" do
  content_type "text/html"
  token = params["token"].to_s.strip
  halt 400, "<h2>Missing token</h2>" if token.empty?

  job = WORKFLOW.approve_job!(token)
  halt 404, "<h2>Invalid or expired link</h2>" unless job

  # Confirmation page
  <<~HTML
    <!doctype html>
    <html>
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>Approved</title>
        <style>
          body { font-family: system-ui, -apple-system, Segoe UI, Roboto, sans-serif; margin: 48px; color: #111; }
          .card { max-width: 720px; padding: 24px; border: 1px solid #e5e7eb; border-radius: 14px; }
          .ok { font-size: 22px; font-weight: 700; margin: 0 0 12px; }
          .muted { color: #555; }
          code { background: #f3f4f6; padding: 2px 6px; border-radius: 6px; }
        </style>
      </head>
      <body>
        <div class="card">
          <p class="ok">Approved ✅</p>
          <p class="muted">Job <code>#{job[:sheet_job_id]}</code> is now approved and ready to offer.</p>
          <p class="muted">You can close this page.</p>
        </div>
      </body>
    </html>
  HTML
end

# --- Start offers manually (job must be approved) ---
post "/jobs/:id/start_offers" do
  res = WORKFLOW.start_offers!(params[:id].to_i)
  halt 404, res.to_json if res[:error] == "job_not_found"
  halt 400, res.to_json if res[:error] == "job_not_approved"
  res.to_json
end

# --- Tick (scheduler hook): timeout old offers and advance ---
post "/tick" do
  WORKFLOW.tick!.to_json
end

# --- Driver response webhook (Twilio / WhatsApp later) ---
post "/webhooks/driver_response" do
  payload = JSON.parse(request.body.read)
  from = payload.fetch("from") # E.164 format
  response = payload.fetch("response")

  job_id = payload["job_id"]
  res = WORKFLOW.driver_response!(from_phone: from, response_text: response, job_id: job_id)
  halt 400, res.to_json unless res[:ok]
  res.to_json
end

get "/offers/:id" do
  require_relative "./lib/db"
  offer = DB[:offers].where(id: params[:id].to_i).first
  halt 404, { error: "not_found" }.to_json unless offer
  offer.to_json
end

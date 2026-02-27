require "time"
require "securerandom"
require_relative "./db"
require_relative "./dispatcher"

class Workflow
  def initialize(base_url:, timeout_minutes:)
    @base_url = base_url
    @timeout_minutes = timeout_minutes
    @dispatcher = Dispatcher.new
  end

  def now_iso
    Time.now.utc.iso8601
  end

  # --- Agents sync (upsert-ish) ---
  def sync_agents!(agents_payload)
    agents = DB[:agents]
    inserted = 0
    updated = 0

    agents_payload.each do |a|
      name = a.fetch("name")
      phone = a.fetch("phone_e164")
      priority = a.fetch("priority").to_i
      active = a.key?("active") ? (a["active"] ? 1 : 0) : 1

      existing = agents.where(phone_e164: phone).first
      if existing
        agents.where(id: existing[:id]).update(name: name, priority: priority, active: active)
        updated += 1
      else
        agents.insert(name: name, phone_e164: phone, priority: priority, active: active)
        inserted += 1
      end
    end

    { inserted: inserted, updated: updated, total: agents.count }
  end

  # --- Job creation ---
  def create_job!(payload)
    jobs = DB[:jobs]
    now = now_iso
    approval_token = SecureRandom.hex(16)

    coordinator_email =
      payload["coordinator_email"] ||
      ENV.fetch("COORDINATOR_EMAIL_DEFAULT", "")

    begin
      id = jobs.insert(
        sheet_job_id: payload.fetch("sheet_job_id"),
        pickup_date: payload["pickup_date"],
        pickup_time: payload["pickup_time"],
        origin: payload["origin"],
        destination: payload["destination"],
        vehicle_type: payload["vehicle_type"],
        coordinator_email: coordinator_email,
        approval_token: approval_token,
        status: "needs_approval",
        created_at: now,
        updated_at: now
      )
    rescue Sequel::UniqueConstraintViolation
      existing = jobs.where(sheet_job_id: payload.fetch("sheet_job_id")).first
      return {
        id: existing[:id],
        status: existing[:status],
        approve_url: approve_url(existing[:approval_token]),
        message: "already_exists"
      }
    end

    { id: id, status: "needs_approval", approve_url: approve_url(approval_token) }
  end

  def approve_job!(token)
    jobs = DB[:jobs]
    job = jobs.where(approval_token: token).first
    return nil unless job

    return job if job[:status] == "approved" || job[:status] == "offering" || job[:status] == "assigned"

    now = now_iso
    jobs.where(id: job[:id]).update(status: "approved", approved_at: now, updated_at: now)
    jobs.where(id: job[:id]).first
  end

  # --- Offer cascade ---
  def start_offers!(job_id)
    jobs = DB[:jobs]
    job = jobs.where(id: job_id).first
    return { ok: false, error: "job_not_found" } unless job
    return { ok: false, error: "job_not_approved" } unless job[:status] == "approved"

    offer_next_agent!(job)
  end

  # Called by scheduler to timeout old offers and advance
  def tick!
    offers = DB[:offers]
    jobs = DB[:jobs]

    cutoff = Time.now.utc - (@timeout_minutes * 60)

    stale = offers.where(status: "sent").all.select do |o|
      Time.parse(o[:sent_at]) < cutoff
    end

    advanced = 0
    timed_out = 0

    stale.each do |offer|
      now = now_iso
      offers.where(id: offer[:id]).update(status: "timed_out", responded_at: now)
      timed_out += 1

      job = jobs.where(id: offer[:job_id]).first
      next unless job
      next unless job[:status] == "offering" # only advance active offers

      res = offer_next_agent!(job)
      advanced += 1 if res[:ok]
    end

    { ok: true, timed_out: timed_out, advanced: advanced }
  end

  # Webhook: driver replies YES/NO
  def driver_response!(from_phone:, response_text:, job_id: nil)
    offers = DB[:offers]
    jobs = DB[:jobs]
    agents = DB[:agents]

    agent = agents.where(phone_e164: from_phone).first
    return { ok: false, error: "unknown_agent" } unless agent

    # Find latest sent offer for this agent (optionally for a specific job)
    scope = offers.where(agent_id: agent[:id], status: "sent")
    scope = scope.where(job_id: job_id) if job_id
    offer = scope.order(Sequel.desc(:sent_at)).first
    return { ok: false, error: "no_open_offer" } unless offer

    job = jobs.where(id: offer[:job_id]).first
    return { ok: false, error: "job_not_found" } unless job

    normalized = response_text.to_s.strip.upcase
    now = now_iso

    if normalized == "YES" || normalized == "Y"
      offers.where(id: offer[:id]).update(status: "accepted", responded_at: now)
      jobs.where(id: job[:id]).update(status: "assigned", assigned_agent_id: agent[:id], updated_at: now)
      return { ok: true, message: "accepted", job_id: job[:id], agent_id: agent[:id] }
    end

    if normalized == "NO" || normalized == "N" || normalized == "DECLINE"
      offers.where(id: offer[:id]).update(status: "declined", responded_at: now)
      # Advance to next agent immediately
      res = offer_next_agent!(job)
      return { ok: true, message: "declined_advanced", next: res }
    end

    { ok: false, error: "unrecognized_response", expected: ["YES", "NO"] }
  end

  private

  def approve_url(token)
    "#{@base_url}/approve?token=#{token}"
  end

  def offer_next_agent!(job)
    offers = DB[:offers]
    agents = DB[:agents]
    jobs = DB[:jobs]

    offered_agent_ids = offers.where(job_id: job[:id]).select_map(:agent_id)

    next_agent = agents
      .where(active: 1)
      .exclude(id: offered_agent_ids)
      .order(:priority)
      .first

    return { ok: true, message: "no_more_agents" } unless next_agent

    now = now_iso
    offer_id = offers.insert(job_id: job[:id], agent_id: next_agent[:id], status: "sent", sent_at: now)

    # Offer “response” endpoint (later: Twilio will hit /webhooks/driver_response)
    offer_url = "#{@base_url}/offers/#{offer_id}"

    @dispatcher.send_offer(job: job, agent: next_agent, offer_url: offer_url)

    jobs.where(id: job[:id]).update(status: "offering", updated_at: now)

    {
      ok: true,
      message: "offer_sent",
      offer_id: offer_id,
      agent: { id: next_agent[:id], name: next_agent[:name], phone_e164: next_agent[:phone_e164] }
    }
  end
end

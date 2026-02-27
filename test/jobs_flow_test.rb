require_relative "./test_helper"
require_relative "../lib/db"

class JobsFlowTest < Minitest::Test
  include Rack::Test::Methods
  include TestHelper

  def setup
    DB[:offers].delete
    DB[:jobs].delete
    DB[:agents].delete

    DB[:agents].insert(name: "A1", phone_e164: "+447700900001", priority: 1, active: 1)
    DB[:agents].insert(name: "A2", phone_e164: "+447700900002", priority: 2, active: 1)
  end

  def test_create_approve_start_offers
    post "/jobs", {
      sheet_job_id: "VC8Y-TEST",
      pickup_date: "30/01/2026",
      pickup_time: "14:30",
      origin: "Leeds",
      destination: "Manchester",
      vehicle_type: "Van"
    }.to_json, { "CONTENT_TYPE" => "application/json" }

    assert_equal 201, last_response.status
    body = JSON.parse(last_response.body)
    assert body["approve_url"]

    token = body["approve_url"].split("token=").last
    get "/approve", { token: token }
    assert_equal 200, last_response.status

    post "/jobs/1/start_offers"
    assert_equal 200, last_response.status
    res = JSON.parse(last_response.body)
    assert_equal "offer_sent", res["message"]
  end
end

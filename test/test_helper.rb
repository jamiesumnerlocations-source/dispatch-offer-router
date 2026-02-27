ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "json"

# Use a separate test DB
ENV["DB_PATH"] = "./db/test.sqlite3"
ENV["BASE_URL"] = "http://localhost:4567"
ENV["OFFER_TIMEOUT_MINUTES"] = "30"
ENV["DISPATCHER_MODE"] = "fake"

require_relative "../db/setup"
require_relative "../app"

module TestHelper
  def app
    Sinatra::Application
  end
end

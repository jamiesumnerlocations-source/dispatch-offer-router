require "dotenv"
Dotenv.load

class Dispatcher
  def initialize(mode: ENV.fetch("DISPATCHER_MODE", "fake"))
    @mode = mode
  end

  # Placeholder for future API/Appscript/webhook integration
  def send_offer(job:, agent:, offer_url:)
    case @mode
    when "fake"
      puts "[FAKE SEND] Offer job=#{job[:sheet_job_id]} to #{agent[:name]} (#{agent[:phone_e164]}) url=#{offer_url}"
      true
    else
      raise "Unsupported DISPATCHER_MODE=#{@mode}"
    end
  end
end

require_relative "../lib/db"

agents = DB[:agents]

seed = [
  { name: "Driver One", phone_e164: "+447700900001", priority: 1, active: 1 },
  { name: "Driver Two", phone_e164: "+447700900002", priority: 2, active: 1 },
  { name: "Driver Three", phone_e164: "+447700900003", priority: 3, active: 1 }
]

seed.each do |row|
  begin
    agents.insert(row)
  rescue Sequel::UniqueConstraintViolation
    # ignore if exists
  end
end

puts "Seeded. Agents now: #{agents.count}"

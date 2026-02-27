require "fileutils"
require_relative "../lib/db"

schema_path = File.expand_path("./schema.sql", __dir__)
sql = File.read(schema_path)

DB.transaction do
  sql.split(";").map(&:strip).reject(&:empty?).each do |stmt|
    DB.run(stmt)
  end
end

puts "DB setup complete."

require "sequel"
require "dotenv"

Dotenv.load

db_path = ENV.fetch("DB_PATH", "./db/dev.sqlite3")
DB = Sequel.sqlite(db_path)

DB.extension :error_sql

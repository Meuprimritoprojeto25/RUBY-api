module Database
  MIGRATIONS_PATH = File.join(ROOT, "db", "migrate").freeze

  class << self
    def prepare!
      mutex.synchronize do
        return if @prepared

        connect!
        create_database_directory!
        migrate!
        @prepared = true
      end
    end

    def connect!
      return if ActiveRecord::Base.connected?

      ActiveRecord::Base.logger = Logger.new($stdout) if ENV["DB_LOG"] == "true"
      ActiveRecord::Base.establish_connection(connection_configuration)
    end

    def migrate!
      connect!
      migration_context.up
    end

    private

    def connection_configuration
      database_url = ENV["DATABASE_URL"]
      return database_url if database_url&.start_with?("sqlite3:")

      {
        adapter: "sqlite3",
        database: ENV.fetch("DATABASE_PATH", File.join(ROOT, "db", "dashboardia.sqlite3")),
        pool: Integer(ENV.fetch("DB_POOL", "5")),
        timeout: Integer(ENV.fetch("DB_TIMEOUT", "5000"))
      }
    end

    def create_database_directory!
      path = ActiveRecord::Base.connection_db_config.database
      return if path.nil? || path == ":memory:" || path.start_with?("file:")

      FileUtils.mkdir_p(File.dirname(path))
    end

    def migration_context
      # Active Record 7.1's migration metadata objects expect the adapter
      # connection, not the connection pool. Passing the pool causes startup
      # to fail when SchemaMigration calls `table_exists?`.
      connection = ActiveRecord::Base.connection
      ActiveRecord::MigrationContext.new(
        [MIGRATIONS_PATH],
        ActiveRecord::SchemaMigration.new(connection),
        ActiveRecord::InternalMetadata.new(connection)
      )
    end

    def mutex
      @mutex ||= Mutex.new
    end
  end
end
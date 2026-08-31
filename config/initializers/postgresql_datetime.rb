# Store Rails datetime columns as PostgreSQL timestamp with time zone values.
ActiveSupport.on_load(:active_record_postgresqladapter) do
  self.datetime_type = :timestamptz
end

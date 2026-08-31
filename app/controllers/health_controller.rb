class HealthController < ApplicationController
  allow_unauthenticated_access

  def show
    if ActiveRecord::Base.connection.select_value("SHOW TIMEZONE") == "UTC"
      head :ok
    else
      head :service_unavailable
    end
  rescue ActiveRecord::ActiveRecordError
    head :service_unavailable
  end
end

require "test_helper"

class MarketData::ImportsControllerTest < ActionDispatch::IntegrationTest
  test "redirects unauthenticated visitors" do
    post market_data_imports_path
    assert_redirected_to new_session_path
  end

  test "authenticated user can trigger market data import job" do
    sign_in_as(users(:one))

    assert_enqueued_with(job: MarketDataImportJob) do
      post market_data_imports_path, headers: { "HTTP_REFERER" => root_path }
    end

    assert_redirected_to root_path
    assert_equal "Market data import job queued in background.", flash[:notice]
  end
end

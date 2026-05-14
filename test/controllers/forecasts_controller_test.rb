require "test_helper"

class ForecastsControllerTest < ActionDispatch::IntegrationTest
  test "index renders the lookup form" do
    get forecasts_path
    assert_response :success
    assert_select "form[action=?]", forecasts_path
    assert_select "input#address"
  end
end

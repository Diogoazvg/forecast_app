# frozen_string_literal: true

require "test_helper"

class OpenMeteoClientTest < ActiveSupport::TestCase
  test "forecast parses current and daily data" do
    stub_open_meteo_forecast(current_temp: 68.4, weather_codes: [ 0, 95 ])

    result = OpenMeteoClient.forecast(lat: 30.27, lng: -97.74)

    assert_equal 68.4, result["current_temp_f"]
    assert_equal 74.0, result["apparent_temp_f"]
    assert_equal 45, result["humidity_pct"]
    assert_equal 80.0, result["high_today_f"]
    assert_equal 60.0, result["low_today_f"]
    assert_equal 2, result["daily"].size
    assert_equal "Clear", result["daily"][0]["summary"]
    assert_equal "Thunderstorm", result["daily"][1]["summary"]
    assert result["fetched_at"].present?
  end

  test "forecast raises OpenMeteoClient::Error on HTTP failure" do
    stub_open_meteo_forecast_error

    error = assert_raises(OpenMeteoClient::Error) do
      OpenMeteoClient.forecast(lat: 1, lng: 2)
    end

    assert_match(/Request failed/, error.message)
  end
end

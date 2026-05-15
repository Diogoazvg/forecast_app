# frozen_string_literal: true

require "test_helper"

class ForecastsControllerTest < ActionDispatch::IntegrationTest
  test "index renders the lookup form" do
    get forecasts_path

    assert_response :success
    assert_select "form[action=?]", forecasts_path
    assert_select "input#address"
  end

  test "index shows forecast for ZIP and cache miss message" do
    stub_zippopotam("90210")
    stub_open_meteo_forecast

    get forecasts_path, params: { zip: "90210" }

    assert_response :success
    assert_select ".forecast__cache--miss", /Fresh pull/
    assert_select "dd", text: "72.5 °F"
    assert_select "h2", "Beverly Hills, CA"
  end

  test "index shows cache hit message on second request" do
    stub_zippopotam("90210")
    stub_open_meteo_forecast

    get forecasts_path, params: { zip: "90210" }
    get forecasts_path, params: { zip: "90210" }

    assert_response :success
    assert_select ".forecast__cache--hit", /cached data/
  end

  test "index shows lookup error for invalid ZIP param" do
    get forecasts_path, params: { zip: "nope" }

    assert_response :success
    assert_select ".forecast__flash--alert", /does not look valid/
  end

  test "index shows error for invalid coord key" do
    get forecasts_path, params: { key: "coord:bad" }

    assert_response :success
    assert_select ".forecast__flash--alert", /not valid/
  end

  test "create redirects to ZIP forecast when address is a ZIP" do
    stub_zippopotam("94022", place_name: "Los Altos", state: "CA", lat: "37.3855", lng: "-122.1147")

    post forecasts_path, params: { address: "94022" }

    assert_redirected_to forecasts_path(zip: "94022")
  end

  test "create redirects to coord key when city has no ZIP" do
    stub_open_meteo_geocoding(
      [
        {
          "name" => "Smalltown",
          "latitude" => 40.0,
          "longitude" => -90.0,
          "country_code" => "US",
          "admin1" => "Illinois",
          "postcodes" => []
        }
      ]
    )

    post forecasts_path, params: { address: "Smalltown, IL" }

    assert_redirected_to forecasts_path(key: "coord:40.0000,-90.0000")
    assert_equal "Smalltown, Illinois", session[:forecast_location_label]
  end

  test "create shows flash when address cannot be resolved" do
    stub_open_meteo_geocoding_empty

    post forecasts_path, params: { address: "Nowhereville" }

    assert_redirected_to forecasts_path
    assert_equal "No US locations matched that search. Try a ZIP or city and state.", flash[:alert]
  end

  test "create shows flash for blank address" do
    post forecasts_path, params: { address: "  " }

    assert_redirected_to forecasts_path
    assert_match(/ZIP code or a city/, flash[:alert])
  end

  test "full flow from form submit to forecast display" do
    stub_zippopotam("90210")
    stub_open_meteo_forecast

    post forecasts_path, params: { address: "90210" }
    follow_redirect!

    assert_response :success
    assert_select "h2", "Beverly Hills, CA"
    assert_select ".forecast__table tbody tr", count: 2
  end
end

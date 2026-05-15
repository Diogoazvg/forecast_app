# frozen_string_literal: true

require "test_helper"

class ForecastLookupTest < ActiveSupport::TestCase
  test "for_zip rejects invalid ZIP format" do
    result = ForecastLookup.for_zip("abc")

    assert_not result.success?
    assert_equal "That ZIP does not look valid.", result.error
    assert_not result.from_cache
  end

  test "for_zip fetches and caches forecast on miss" do
    stub_zippopotam("90210")
    stub_open_meteo_forecast

    result = ForecastLookup.for_zip("90210")

    assert result.success?
    assert_not result.from_cache
    assert_equal 72.5, result.forecast["current_temp_f"]
    assert_equal "Beverly Hills, CA", result.forecast["location_label"]

    cached = ForecastLookup.for_zip("90210")

    assert cached.success?
    assert cached.from_cache
    assert_equal 72.5, cached.forecast["current_temp_f"]
  end

  test "for_zip returns error when ZIP is unknown" do
    stub_zippopotam_not_found("00000")

    result = ForecastLookup.for_zip("00000")

    assert_not result.success?
    assert_match(/could not find/, result.error)
  end

  test "for_zip returns error when weather API fails" do
    stub_zippopotam("90210")
    stub_open_meteo_forecast_error

    result = ForecastLookup.for_zip("90210")

    assert_not result.success?
    assert_match(/Request failed/, result.error)
  end

  test "for_coord_key fetches forecast for valid coord key" do
    stub_open_meteo_forecast

    result = ForecastLookup.for_coord_key("coord:30.2672,-97.7431", "Austin, Texas")

    assert result.success?
    assert_not result.from_cache
    assert_equal "Austin, Texas", result.forecast["location_label"]
  end

  test "for_coord_key uses default label when none given" do
    stub_open_meteo_forecast

    result = ForecastLookup.for_coord_key("coord:30.2672,-97.7431", nil)

    assert_equal "Selected location", result.forecast["location_label"]
  end

  test "for_coord_key rejects invalid coord key" do
    result = ForecastLookup.for_coord_key("coord:not-valid", "Somewhere")

    assert_not result.success?
    assert_equal "That location link is not valid.", result.error
  end

  test "for_coord_key serves cached data on repeat lookup" do
    stub_open_meteo_forecast

    ForecastLookup.for_coord_key("coord:40.0,-90.0", "Testville")
    cached = ForecastLookup.for_coord_key("coord:40.0,-90.0", "Ignored")

    assert cached.from_cache
    assert_equal "Testville", cached.forecast["location_label"]
  end
end

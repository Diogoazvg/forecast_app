# frozen_string_literal: true

require "test_helper"

class AddressZipResolverTest < ActiveSupport::TestCase
  test "normalize_zip extracts five digits" do
    assert_equal "90210", AddressZipResolver.normalize_zip("90210-1234")
    assert_equal "94022", AddressZipResolver.normalize_zip(" 94022 ")
  end

  test "normalize_zip returns nil when too short" do
    assert_nil AddressZipResolver.normalize_zip("1234")
    assert_nil AddressZipResolver.normalize_zip("")
  end

  test "resolve rejects blank input" do
    result = AddressZipResolver.resolve("   ")

    assert result.failure?
    assert_match(/ZIP code or a city/, result.error)
  end

  test "resolve looks up a US ZIP via Zippopotam" do
    stub_zippopotam("90210")

    result = AddressZipResolver.resolve("90210")

    assert result.success?
    assert_equal "90210", result.cache_key
    assert_in_delta 34.0901, result.lat, 0.0001
    assert_in_delta(-118.4065, result.lng, 0.0001)
    assert_equal "Beverly Hills, CA", result.label
  end

  test "resolve accepts ZIP+4 format" do
    stub_zippopotam("94022", place_name: "Los Altos", state: "CA", lat: "37.3855", lng: "-122.1147")

    result = AddressZipResolver.resolve("94022-1234")

    assert result.success?
    assert_equal "94022", result.cache_key
  end

  test "from_zip handles unknown ZIP" do
    stub_zippopotam_not_found("00000")

    result = AddressZipResolver.from_zip("00000")

    assert result.failure?
    assert_match(/could not find/, result.error)
  end

  test "resolve looks up city and state via Open-Meteo geocoding" do
    stub_open_meteo_geocoding(
      [
        {
          "name" => "Austin",
          "latitude" => 30.2672,
          "longitude" => -97.7431,
          "country_code" => "US",
          "admin1" => "Texas",
          "postcodes" => [ "78701" ]
        }
      ]
    )

    result = AddressZipResolver.resolve("Austin, TX")

    assert result.success?
    assert_equal "78701", result.cache_key
    assert_equal "Austin, Texas", result.label
  end

  test "resolve uses coord cache key when geocoding has no ZIP" do
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

    result = AddressZipResolver.resolve("Smalltown, IL")

    assert result.success?
    assert_equal "coord:40.0000,-90.0000", result.cache_key
  end

  test "resolve picks state when multiple cities share a name" do
    stub_open_meteo_geocoding(
      [
        {
          "name" => "Springfield",
          "latitude" => 39.7817,
          "longitude" => -89.6501,
          "country_code" => "US",
          "admin1" => "Illinois",
          "postcodes" => [ "62701" ]
        },
        {
          "name" => "Springfield",
          "latitude" => 37.2089,
          "longitude" => -93.2923,
          "country_code" => "US",
          "admin1" => "Missouri",
          "postcodes" => [ "65801" ]
        }
      ]
    )

    result = AddressZipResolver.resolve("Springfield, IL")

    assert result.success?
    assert_equal "62701", result.cache_key
    assert_equal "Springfield, Illinois", result.label
  end

  test "resolve fails when geocoding returns no US matches" do
    stub_open_meteo_geocoding_empty

    result = AddressZipResolver.resolve("Nowhereville")

    assert result.failure?
    assert_match(/No US locations/, result.error)
  end

  test "coord_cache_key rounds coordinates" do
    assert_equal "coord:30.2672,-97.7431", AddressZipResolver.coord_cache_key(30.26715, -97.74312)
  end
end

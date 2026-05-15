# frozen_string_literal: true

require "webmock/minitest"

WebMock.disable_net_connect!(allow_localhost: true)

module ApiStubs
  def stub_zippopotam(zip, place_name: "Beverly Hills", state: "CA", lat: "34.0901", lng: "-118.4065")
    stub_request(:get, "https://api.zippopotam.us/us/#{zip}")
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          "country" => "United States",
          "places" => [
            {
              "place name" => place_name,
              "state abbreviation" => state,
              "latitude" => lat,
              "longitude" => lng
            }
          ]
        }.to_json
      )
  end

  def stub_zippopotam_not_found(zip)
    stub_request(:get, "https://api.zippopotam.us/us/#{zip}")
      .to_return(status: 404, body: "Not Found")
  end

  def stub_open_meteo_geocoding(results)
    stub_request(:get, %r{\Ahttps://geocoding-api\.open-meteo\.com/v1/search})
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: { "results" => results }.to_json
      )
  end

  def stub_open_meteo_geocoding_empty
    stub_open_meteo_geocoding([])
  end

  def stub_open_meteo_forecast(lat: nil, lng: nil, current_temp: 72.5, weather_codes: [ 0, 61 ])
    stub_request(:get, %r{\Ahttps://api\.open-meteo\.com/v1/forecast})
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          "current" => {
            "temperature_2m" => current_temp,
            "relative_humidity_2m" => 45,
            "apparent_temperature" => 74.0
          },
          "daily" => {
            "time" => [ "2026-05-15", "2026-05-16" ],
            "temperature_2m_max" => [ 80.0, 82.0 ],
            "temperature_2m_min" => [ 60.0, 62.0 ],
            "weather_code" => weather_codes
          }
        }.to_json
      )
  end

  def stub_open_meteo_forecast_error
    stub_request(:get, %r{\Ahttps://api\.open-meteo\.com/v1/forecast})
      .to_return(status: 503, body: "Unavailable")
  end
end

ActiveSupport::TestCase.include ApiStubs

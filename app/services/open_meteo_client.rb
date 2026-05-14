# frozen_string_literal: true

class OpenMeteoClient
  class Error < StandardError; end

  class << self
    def forecast(lat:, lng:)
      url = [
        "https://api.open-meteo.com/v1/forecast",
        "?latitude=#{lat}",
        "&longitude=#{lng}",
        "&current=temperature_2m,relative_humidity_2m,apparent_temperature",
        "&daily=temperature_2m_max,temperature_2m_min,weather_code",
        "&temperature_unit=fahrenheit",
        "&timezone=auto",
        "&forecast_days=7"
      ].join

      raw = HttpJson.get(url)
      parse(raw)
    rescue HttpJson::Error => e
      raise Error, e.message
    end

    private

    def parse(data)
      current = data["current"] || {}
      daily = data["daily"] || {}
      times = daily["time"] || []
      highs = daily["temperature_2m_max"] || []
      lows = daily["temperature_2m_min"] || []
      codes = daily["weather_code"] || []

      rows =
        times.each_with_index.map do |date, i|
          {
            "date" => date,
            "high_f" => highs[i]&.round(1),
            "low_f" => lows[i]&.round(1),
            "summary" => wmo_summary(codes[i])
          }
        end

      today = rows[0]

      {
        "current_temp_f" => current["temperature_2m"]&.round(1),
        "apparent_temp_f" => current["apparent_temperature"]&.round(1),
        "humidity_pct" => current["relative_humidity_2m"],
        "high_today_f" => today&.fetch("high_f", nil),
        "low_today_f" => today&.fetch("low_f", nil),
        "daily" => rows,
        "fetched_at" => Time.current.iso8601
      }
    end

    def wmo_summary(code)
      return nil if code.nil?

      case code.to_i
      when 0 then "Clear"
      when 1, 2, 3 then "Mainly clear to overcast"
      when 45, 48 then "Fog"
      when 51, 53, 55 then "Drizzle"
      when 61, 63, 65 then "Rain"
      when 71, 73, 75 then "Snow"
      when 80, 81, 82 then "Rain showers"
      when 95, 96, 99 then "Thunderstorm"
      else "Mixed conditions"
      end
    end
  end
end

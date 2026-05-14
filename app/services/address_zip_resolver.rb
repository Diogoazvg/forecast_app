# frozen_string_literal: true

class AddressZipResolver
  Result = Struct.new(:ok, :cache_key, :lat, :lng, :label, :error, keyword_init: true) do
    def success? = ok
    def failure? = !ok
  end

  US_ZIP = /\A(\d{5})(?:-\d{4})?\z/

  US_STATE_ABBR = {
    "AL" => "Alabama", "AK" => "Alaska", "AZ" => "Arizona", "AR" => "Arkansas", "CA" => "California",
    "CO" => "Colorado", "CT" => "Connecticut", "DE" => "Delaware", "DC" => "District of Columbia", "FL" => "Florida",
    "GA" => "Georgia", "HI" => "Hawaii", "ID" => "Idaho", "IL" => "Illinois", "IN" => "Indiana", "IA" => "Iowa",
    "KS" => "Kansas", "KY" => "Kentucky", "LA" => "Louisiana", "ME" => "Maine", "MD" => "Maryland",
    "MA" => "Massachusetts", "MI" => "Michigan", "MN" => "Minnesota", "MS" => "Mississippi", "MO" => "Missouri",
    "MT" => "Montana", "NE" => "Nebraska", "NV" => "Nevada", "NH" => "New Hampshire", "NJ" => "New Jersey",
    "NM" => "New Mexico", "NY" => "New York", "NC" => "North Carolina", "ND" => "North Dakota", "OH" => "Ohio",
    "OK" => "Oklahoma", "OR" => "Oregon", "PA" => "Pennsylvania", "RI" => "Rhode Island", "SC" => "South Carolina",
    "SD" => "South Dakota", "TN" => "Tennessee", "TX" => "Texas", "UT" => "Utah", "VT" => "Vermont",
    "VA" => "Virginia", "WA" => "Washington", "WV" => "West Virginia", "WI" => "Wisconsin", "WY" => "Wyoming"
  }.freeze

  class << self
    def normalize_zip(raw)
      digits = raw.to_s.gsub(/\D/, "")
      return nil if digits.length < 5

      digits[0, 5]
    end

    def resolve(input)
      query = input.to_s.strip
      return Result.new(ok: false, error: "Please enter a US ZIP code or a city and state.") if query.blank?

      if (m = query.match(US_ZIP))
        from_zip(m[1])
      else
        from_place_name(query)
      end
    end

    def from_zip(zip5)
      data = HttpJson.get("https://api.zippopotam.us/us/#{zip5}")
      place = data["places"]&.first
      unless place
        return Result.new(ok: false, error: "We could not find that US ZIP code.")
      end

      lat = place["latitude"].to_f
      lng = place["longitude"].to_f
      label = [ place["place name"], place["state abbreviation"] ].compact.join(", ")
      Result.new(ok: true, cache_key: zip5, lat: lat, lng: lng, label: label.presence || "ZIP #{zip5}")
    rescue HttpJson::Error
      Result.new(ok: false, error: "We could not find that US ZIP code.")
    end

    def from_place_name(query)
      city_name, region_hint = split_city_and_region(query.to_s.strip)

      uri = URI("https://geocoding-api.open-meteo.com/v1/search")
      uri.query = URI.encode_www_form(
        name: city_name,
        count: 20,
        language: "en",
        format: "json",
        countryCode: "US"
      )

      data = HttpJson.get(uri.to_s)
      results = data["results"] || []
      us_results = results.select { |r| r["country_code"] == "US" }

      hit = pick_us_place(us_results, region_hint) || us_results.first

      unless hit
        return Result.new(ok: false, error: "No US locations matched that search. Try a ZIP or city and state.")
      end

      lat = hit["latitude"].to_f
      lng = hit["longitude"].to_f
      label = [ hit["name"], hit["admin1"] ].compact.join(", ")

      zip_key = first_us_zip(hit["postcodes"])
      cache_key = zip_key || coord_cache_key(lat, lng)

      Result.new(ok: true, cache_key: cache_key, lat: lat, lng: lng, label: label.presence || "Selected location")
    rescue HttpJson::Error
      Result.new(ok: false, error: "Location lookup failed. Please try again in a moment.")
    end

    def coord_cache_key(lat, lng)
      "coord:#{format('%.4f', lat)},#{format('%.4f', lng)}"
    end

    private

    def split_city_and_region(query)
      if (m = query.match(/\A(.+),\s*(.+)\z/))
        [ m[1].strip, m[2].strip ]
      else
        [ query, nil ]
      end
    end

    def pick_us_place(us_results, region_hint)
      return nil if region_hint.blank? || us_results.empty?

      if (m = region_hint.match(/\A([A-Za-z]{2})\z/))
        want_admin1 = US_STATE_ABBR[m[1].upcase]
        return us_results.find { |r| r["admin1"] == want_admin1 } if want_admin1
      end

      hint = region_hint.downcase
      us_results.find { |r| r["admin1"]&.casecmp?(region_hint) } ||
        us_results.find { |r| r["admin1"]&.downcase&.include?(hint) }
    end

    def first_us_zip(postcodes)
      Array(postcodes).map(&:to_s).grep(/\A\d{5}/).map { |z| z[/\A(\d{5})/, 1] }.first
    end
  end
end

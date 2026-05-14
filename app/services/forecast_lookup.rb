# frozen_string_literal: true

class ForecastLookup
  CACHE_PREFIX = "forecast/v1"
  CACHE_TTL = 30.minutes

  LookupResult = Struct.new(:forecast, :from_cache, :error, keyword_init: true) do
    def success? = error.nil? && forecast.present?
  end

  class << self
    def for_zip(zip_param)
      zip = AddressZipResolver.normalize_zip(zip_param)
      unless zip
        return LookupResult.new(forecast: nil, from_cache: false, error: "That ZIP does not look valid.")
      end

      full_key = "#{CACHE_PREFIX}/#{zip}"
      if (cached = Rails.cache.read(full_key))
        return LookupResult.new(forecast: cached.stringify_keys, from_cache: true)
      end

      resolved = AddressZipResolver.from_zip(zip)
      unless resolved.success?
        return LookupResult.new(forecast: nil, from_cache: false, error: resolved.error)
      end

      store_fresh(full_key, resolved.lat, resolved.lng, resolved.label)
    end

    def for_coord_key(cache_key, location_label)
      full_key = "#{CACHE_PREFIX}/#{cache_key}"
      if (cached = Rails.cache.read(full_key))
        return LookupResult.new(forecast: cached.stringify_keys, from_cache: true)
      end

      lat, lng = parse_coord_cache_key(cache_key)
      unless lat && lng
        return LookupResult.new(forecast: nil, from_cache: false, error: "That location link is not valid.")
      end

      label = location_label.presence || "Selected location"
      store_fresh(full_key, lat, lng, label)
    end

    private

    def store_fresh(full_key, lat, lng, label)
      payload = OpenMeteoClient.forecast(lat: lat, lng: lng)
      payload["location_label"] = label if label.present?

      Rails.cache.write(full_key, payload, expires_in: CACHE_TTL)
      LookupResult.new(forecast: payload.stringify_keys, from_cache: false)
    rescue OpenMeteoClient::Error, HttpJson::Error => e
      LookupResult.new(forecast: nil, from_cache: false, error: e.message)
    end

    def parse_coord_cache_key(key)
      return [ nil, nil ] unless key.to_s.start_with?("coord:")

      rest = key.delete_prefix("coord:")
      lat_s, lng_s = rest.split(",", 2)
      lat = lat_s&.to_f
      lng = lng_s&.to_f
      return [ nil, nil ] unless lat && lng && lat.finite? && lng.finite?
      return [ nil, nil ] unless lat.between?(-90, 90) && lng.between?(-180, 180)

      [ lat, lng ]
    end
  end
end

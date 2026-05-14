# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module HttpJson
  class Error < StandardError; end

  def self.get(url_string)
    uri = URI.parse(url_string)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.open_timeout = 3
    http.read_timeout = 12

    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = "ForecastApp/1.0"

    response = http.request(request)
    unless response.is_a?(Net::HTTPSuccess)
      raise Error, "Request failed (#{response.code})"
    end

    JSON.parse(response.body)
  end
end

# frozen_string_literal: true

require "test_helper"

class HttpJsonTest < ActiveSupport::TestCase
  test "get returns parsed JSON on success" do
    stub_request(:get, "https://example.com/data")
      .to_return(status: 200, body: { "ok" => true }.to_json, headers: { "Content-Type" => "application/json" })

    assert_equal({ "ok" => true }, HttpJson.get("https://example.com/data"))
  end

  test "get raises HttpJson::Error on non-success response" do
    stub_request(:get, "https://example.com/missing")
      .to_return(status: 404, body: "Not Found")

    error = assert_raises(HttpJson::Error) do
      HttpJson.get("https://example.com/missing")
    end

    assert_match(/404/, error.message)
  end
end

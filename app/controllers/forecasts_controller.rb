class ForecastsController < ApplicationController
  def index
    @address = params[:address]

    @lookup =
      if params[:zip].present?
        ForecastLookup.for_zip(params[:zip])
      elsif (key = params[:key].to_s).start_with?("coord:") && key.bytesize < 96
        label = session.delete(:forecast_location_label)
        ForecastLookup.for_coord_key(key, label)
      end

    @forecast = @lookup.forecast.with_indifferent_access if @lookup&.success?
  end

  def create
    resolved = AddressZipResolver.resolve(params[:address])
    unless resolved.success?
      redirect_to forecasts_path, alert: resolved.error
      return
    end

    if resolved.cache_key.match?(/\A\d{5}\z/)
      redirect_to forecasts_path(zip: resolved.cache_key)
    else
      session[:forecast_location_label] = resolved.label
      redirect_to forecasts_path(key: resolved.cache_key)
    end
  end
end

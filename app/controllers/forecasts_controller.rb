class ForecastsController < ApplicationController
  def index

  end

  def create
    address = params[:address].to_s.strip
    if address.blank?
      redirect_to forecasts_path, alert: "Please enter a US ZIP code or a city and state."
      return
    end

    redirect_to forecasts_path, notice: "Lookup for \"#{address}\" will run here after the next change (API + caching)."
  end
end

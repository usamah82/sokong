class LocalitiesController < ApplicationController
  wrap_parameters false

  def suggestion
    errors = coordinate_errors
    if errors.any?
      render json: { error: validation_error(errors) }, status: :unprocessable_content
    else
      render json: { locality: suggested_name }
    end
  end

  private
    def suggested_name
      locality = Locality.nearest([ @latitude, @longitude ])
      return if locality.nil?

      { name: locality.name }
    end

    def coordinate_errors
      latitude = params[:latitude]
      longitude = params[:longitude]
      if missing?(latitude) || missing?(longitude)
        return [ { field: "latitude", message: "Latitude and longitude must both be present", detail: "must be present with longitude" } ]
      end

      errors = []
      @latitude = read_coordinate(latitude, "latitude", "Latitude", -90..90, errors)
      @longitude = read_coordinate(longitude, "longitude", "Longitude", -180..180, errors)
      errors
    end

    def missing?(raw)
      raw.nil? || (raw.is_a?(String) && raw.strip.empty?)
    end

    def read_coordinate(raw, field, label, range, errors)
      text = raw.is_a?(String) ? raw.strip : nil
      unless text&.match?(/\A-?(?:\d+\.?\d*|\.\d+)\z/)
        errors << { field:, message: "#{label} is not a number", detail: "is not a number" }
        return
      end

      number = Float(text)
      unless number.finite? && range.cover?(number)
        errors << { field:, message: "#{label} is out of range", detail: "is out of range" }
        return
      end

      number
    end

    def validation_error(errors)
      {
        code: "VALIDATION_ERROR",
        message: errors.first[:message],
        details: errors.each_with_object({}) do |error, details|
          (details[error[:field]] ||= []) << error[:detail]
        end
      }
    end
end

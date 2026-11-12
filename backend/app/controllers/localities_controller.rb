class LocalitiesController < ApplicationController
  wrap_parameters false

  def update
    require_account
    return if performed?

    locality = linked_locality
    return render_not_found unless locality

    if (error = boundary_error(locality))
      render json: { error: error }, status: :unprocessable_content
    else
      render json: locality_json(locality.reload)
    end
  end

  def suggestion
    errors = coordinate_errors
    if errors.any?
      render json: { error: validation_error(errors) }, status: :unprocessable_content
    else
      render json: { locality: suggested_name }
    end
  end

  private
    def linked_locality
      return unless current_account.role == "worker"

      Locality.where(id: current_account.locality_assignments.select(:locality_id)).find_by(id: params[:id])
    end

    def render_not_found
      render json: { error: { code: "NOT_FOUND", message: "Not found" } }, status: :not_found
    end

    def locality_json(locality)
      {
        id: locality.id,
        name: locality.name,
        latitude: locality.latitude&.to_f,
        longitude: locality.longitude&.to_f,
        radius_metres: locality.radius_metres
      }
    end

    def boundary_error(locality)
      errors = []
      name, name_sent = boundary_name(errors)
      latitude, longitude, coordinates_sent = boundary_coordinates(errors)
      radius, radius_sent = boundary_radius(errors)
      return validation_error(errors) if errors.any?

      latitude = locality.latitude unless coordinates_sent
      longitude = locality.longitude unless coordinates_sent
      radius = locality.radius_metres unless radius_sent
      if !radius.nil? && (latitude.nil? || longitude.nil?)
        errors << { field: "radius_metres", message: "Radius requires a center", detail: "requires a center" }
        return validation_error(errors)
      end

      locality.update!(
        name: name_sent ? name : locality.name,
        latitude: latitude,
        longitude: longitude,
        radius_metres: radius
      )
      nil
    end

    def boundary_name(errors)
      return [ nil, false ] unless params.key?("name")

      raw = params[:name]
      unless raw.is_a?(String)
        errors << { field: "name", message: "Name is invalid", detail: "is invalid" }
        return [ nil, true ]
      end

      cleaned = raw.strip.gsub(/\s+/, " ")
      if cleaned.empty?
        errors << { field: "name", message: "Name is required", detail: "is required" }
      elsif cleaned.length > 200
        errors << { field: "name", message: "Name is too long", detail: "is too long" }
      end
      [ cleaned, true ]
    end

    def boundary_coordinates(errors)
      lat_sent = params.key?("latitude")
      lng_sent = params.key?("longitude")
      return [ nil, nil, false ] unless lat_sent || lng_sent

      unless lat_sent && lng_sent && ((params[:latitude].nil? && params[:longitude].nil?) || params[:latitude].present? && params[:longitude].present?)
        errors << {
          field: "latitude",
          message: "Latitude and longitude must both be present",
          detail: "must be present with longitude"
        }
        return [ nil, nil, true ]
      end

      return [ nil, nil, true ] if params[:latitude].nil?

      latitude = boundary_number(params[:latitude], "latitude", "Latitude", -90..90, errors)
      longitude = boundary_number(params[:longitude], "longitude", "Longitude", -180..180, errors)
      [ latitude, longitude, true ]
    end

    def boundary_radius(errors)
      return [ nil, false ] unless params.key?("radius_metres")
      return [ nil, true ] if params[:radius_metres].nil?

      number = boundary_integer(params[:radius_metres], errors)
      if number && !(1..200_000).cover?(number)
        errors << { field: "radius_metres", message: "Radius is out of range", detail: "is out of range" }
      end
      [ number, true ]
    end

    def boundary_integer(raw, errors)
      number = raw.is_a?(Integer) ? raw : nil
      number = Integer(raw, 10) if number.nil? && raw.is_a?(String) && raw.match?(/\A-?\d+\z/)
      return number if number

      errors << { field: "radius_metres", message: "Radius is invalid", detail: "is invalid" }
      nil
    end

    def boundary_number(raw, field, label, range, errors)
      number = raw.is_a?(Numeric) && !raw.is_a?(String) ? raw.to_f : nil
      if number.nil? && raw.is_a?(String) && raw.strip.match?(/\A-?(?:\d+\.?\d*|\.\d+)\z/)
        number = Float(raw.strip)
      end
      unless number&.finite? && range.cover?(number)
        detail = number.nil? ? "is not a number" : "is out of range"
        message = number.nil? ? "#{label} is not a number" : "#{label} is out of range"
        errors << { field:, message:, detail: }
        return
      end

      number
    end

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

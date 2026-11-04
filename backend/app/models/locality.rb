class Locality < ApplicationRecord
  EARTH_RADIUS_METRES = 6_371_000

  has_many :locality_assignments

  def self.claim(place_name:, point:)
    matches = fitting(place_name, point)
    return create_from_submission!(place_name) if matches.empty?

    staffed = matches.select(&:staffed?)
    closest(staffed.empty? ? matches : staffed, point)
  end

  def self.nearest(point)
    return if point.nil?

    matches = all.select { |locality| center?(locality) }
    return if matches.empty?

    matches.min_by { |locality| [ distance_metres(locality, point), locality.created_at ] }
  end

  def self.same_name?(left, right)
    fold_name(left) == fold_name(right)
  end

  def staffed?
    locality_assignments.exists?
  end

  class << self
    private
      def fitting(place_name, point)
        folded = fold_name(place_name)
        all.select { |locality| fold_name(locality.name) == folded || covers?(locality, point) }
      end

      def create_from_submission!(place_name)
        create!(name: collapse_whitespace(place_name))
      end

      def closest(matches, point)
        matches.min_by { |locality| [ distance_rank(locality, point), locality.created_at ] }
      end

      def covers?(locality, point)
        return false if point.nil? || !center?(locality) || locality.radius_metres.nil?

        distance_metres(locality, point) <= locality.radius_metres
      end

      def distance_rank(locality, point)
        return Float::INFINITY if point.nil? || !center?(locality)

        distance_metres(locality, point)
      end

      def center?(locality)
        !locality.latitude.nil? && !locality.longitude.nil?
      end

      def distance_metres(locality, point)
        haversine_metres(point[0], point[1], locality.latitude, locality.longitude)
      end

      def haversine_metres(from_lat, from_lng, to_lat, to_lng)
        delta_phi = radians(to_lat.to_f - from_lat.to_f)
        delta_lambda = radians(to_lng.to_f - from_lng.to_f)
        phi1 = radians(from_lat)
        phi2 = radians(to_lat)

        a = Math.sin(delta_phi / 2)**2 +
          Math.cos(phi1) * Math.cos(phi2) * Math.sin(delta_lambda / 2)**2
        c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
        EARTH_RADIUS_METRES * c
      end

      def radians(degrees)
        degrees.to_f * Math::PI / 180
      end

      def fold_name(name)
        collapse_whitespace(name).downcase(:fold)
      end

      def collapse_whitespace(name)
        name.to_s.strip.gsub(/\s+/, " ")
      end
  end
end

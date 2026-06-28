# frozen_string_literal: true

module AiResearchAGL
  module PathComponentArray
    # PathSampler turns a single straight Edge into an ordered list of
    # placement points spaced at a fixed pitch.
    #
    # v0.1 only supports a single Edge. Polyline / Curve support is future work.
    module PathSampler
      # Small tolerance (in SketchUp internal inches) used so floating point
      # rounding does not drop a point that sits exactly on the end limit.
      EPSILON = 1.0e-6

      # Result of sampling an edge.
      #   points    - Array<Geom::Point3d> in model coordinates
      #   direction - Geom::Vector3d, unit vector from edge start to end
      #   length    - Length of the edge (SketchUp internal units)
      Result = Struct.new(:points, :direction, :length)

      # Sample an edge at a fixed pitch.
      #
      # All length arguments are SketchUp Length values (internal inches).
      # Raises ArgumentError with a user friendly message on invalid input so
      # the caller can show it directly in a message box.
      def self.sample_edge(edge, pitch, start_offset, end_offset)
        start_point = edge.start.position
        end_point   = edge.end.position
        vector      = end_point - start_point
        length      = vector.length

        raise ArgumentError, 'The selected edge has zero length.' if length <= 0
        raise ArgumentError, 'Pitch must be greater than 0.'      if pitch <= 0

        if start_offset.negative? || end_offset.negative?
          raise ArgumentError, 'Start offset and end offset cannot be negative.'
        end

        direction   = vector.normalize
        first_dist  = start_offset
        last_dist   = length - end_offset

        if first_dist > last_dist
          raise ArgumentError,
                'No room to place components. Reduce the start/end offsets or ' \
                'check the pitch against the edge length.'
        end

        points   = []
        distance = first_dist
        while distance <= last_dist + EPSILON
          points << start_point.offset(direction, distance)
          distance += pitch
        end

        raise ArgumentError, 'No placement points were generated.' if points.empty?

        Result.new(points, direction, length)
      end
    end
  end
end

# frozen_string_literal: true

module AiResearchAGL
  module PathComponentArray
    # InstancePlacer drops copies of a component definition at each sampled
    # point and applies the requested orientation.
    #
    # v0.1 placed the component *origin* on each path point (no centre / end
    # alignment) and rotated around the global Z axis using a single edge
    # direction. v0.2 keeps the same placement rule, but rotates each instance
    # using the tangent of the path segment it sits on, so orientation follows
    # a polyline's turns. Full 3D pose control for arbitrarily tilted paths is
    # still future work.
    module InstancePlacer
      ORIGIN = Geom::Point3d.new(0, 0, 0)
      Z_AXIS = Geom::Vector3d.new(0, 0, 1)

      # Place an instance of +definition+ at every point.
      #
      #   target_entities  - Sketchup::Entities to add the instances to
      #   definition       - Sketchup::ComponentDefinition to copy
      #   source_transform - Geom::Transformation of the selected instance
      #                      (used to keep orientation when follow_path is false)
      #   points           - Array<Geom::Point3d>
      #   tangents         - Array<Geom::Vector3d>, unit direction of the path
      #                      segment at each point (same size as points)
      #   follow_path      - true to align each instance with its segment tangent
      #   angle_offset_deg - extra rotation around Z, in degrees
      #
      # Returns the array of created Sketchup::ComponentInstance objects.
      def self.place(target_entities, definition, source_transform, points,
                     tangents, follow_path, angle_offset_deg)
        angle_rad     = angle_offset_deg.degrees
        fixed_orient  = follow_path ? nil : fixed_orientation(source_transform, angle_rad)

        points.each_with_index.map do |point, i|
          orient    = follow_path ? path_orientation(tangents[i], angle_rad) : fixed_orient
          transform = Geom::Transformation.new(point) * orient
          target_entities.add_instance(definition, transform)
        end
      end

      # Orientation that turns the component to face the given tangent
      # direction (Z-axis yaw only), plus the extra angle offset.
      def self.path_orientation(tangent, angle_rad)
        yaw = Math.atan2(tangent.y, tangent.x) + angle_rad
        Geom::Transformation.rotation(ORIGIN, Z_AXIS, yaw)
      end

      # Orientation shared by every instance when follow_path is false: keep
      # the source instance's orientation, plus the extra angle offset.
      def self.fixed_orientation(source_transform, angle_rad)
        base  = rotation_only(source_transform)
        extra = Geom::Transformation.rotation(ORIGIN, Z_AXIS, angle_rad)
        extra * base
      end

      # Extract the rotation part of a transformation, dropping translation and
      # uniform scale, so copies keep the source instance's orientation.
      def self.rotation_only(transform)
        x_axis = safe_normalize(transform.xaxis)
        y_axis = safe_normalize(transform.yaxis)
        z_axis = safe_normalize(transform.zaxis)
        Geom::Transformation.axes(ORIGIN, x_axis, y_axis, z_axis)
      end

      def self.safe_normalize(vector)
        vector.length.zero? ? vector : vector.normalize
      end
    end
  end
end

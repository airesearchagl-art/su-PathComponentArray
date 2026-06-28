# frozen_string_literal: true

module AiResearchAGL
  module PathComponentArray
    # InstancePlacer drops copies of a component definition at each sampled
    # point and applies the requested orientation.
    #
    # v0.1 places the component *origin* on each path point (no centre / end
    # alignment) and rotates around the global Z axis. Full 3D pose control for
    # arbitrarily tilted edges is future work.
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
      #   direction        - Geom::Vector3d, unit direction of the edge
      #   follow_path      - true to align instances with the edge direction
      #   angle_offset_deg - extra rotation around Z, in degrees
      #
      # Returns the array of created Sketchup::ComponentInstance objects.
      def self.place(target_entities, definition, source_transform, points,
                     direction, follow_path, angle_offset_deg)
        angle_rad = angle_offset_deg.degrees
        orient    = orientation(source_transform, direction, follow_path, angle_rad)

        points.map do |point|
          transform = Geom::Transformation.new(point) * orient
          target_entities.add_instance(definition, transform)
        end
      end

      # Build the orientation (rotation only) shared by every placed instance.
      def self.orientation(source_transform, direction, follow_path, angle_rad)
        if follow_path
          yaw = Math.atan2(direction.y, direction.x) + angle_rad
          Geom::Transformation.rotation(ORIGIN, Z_AXIS, yaw)
        else
          base  = rotation_only(source_transform)
          extra = Geom::Transformation.rotation(ORIGIN, Z_AXIS, angle_rad)
          extra * base
        end
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

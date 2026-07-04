# frozen_string_literal: true

module AiResearchAGL
  module PathComponentArray
    # PathSampler turns one or more connected Edges into an ordered list of
    # placement points (with a tangent direction each) spaced at a fixed pitch.
    #
    # v0.2 supports a single Edge or a continuous chain of Edges (a polyline).
    # Branching, disconnected selections, and closed loops are rejected with a
    # friendly ArgumentError. Curves, random pitch and gradual angle changes
    # are still future work.
    module PathSampler
      # Small tolerance (in SketchUp internal inches) used so floating point
      # rounding does not drop a point that sits exactly on a segment/end limit.
      EPSILON = 1.0e-6

      # A validated, ordered path built from one or more connected edges.
      #   edges    - Array<Sketchup::Edge> in traversal order
      #   vertices - Array<Sketchup::Vertex>, size == edges.size + 1;
      #              vertices[i] / vertices[i + 1] are the endpoints of
      #              edges[i], already oriented in traversal order.
      OrderedPath = Struct.new(:edges, :vertices)

      # Result of sampling a path.
      #   points       - Array<Geom::Point3d> in model coordinates
      #   tangents     - Array<Geom::Vector3d>, unit vector per point (the
      #                  direction of the segment the point sits on)
      #   total_length - total length of the path (SketchUp internal units)
      Result = Struct.new(:points, :tangents, :total_length)

      # Validate and order a selection of edges into a single connected,
      # non-branching, open path.
      #
      # Raises ArgumentError with a user friendly message for:
      #   - edges that branch at a shared vertex
      #   - edges that form a closed loop (unsupported in v0.2)
      #   - edges that do not form a single continuous chain
      def self.order_edges(edges)
        edges = edges.uniq
        raise ArgumentError, 'Select at least one Edge to build a path.' if edges.empty?

        return OrderedPath.new(edges, [edges.first.start, edges.first.end]) if edges.size == 1

        adjacency, vertex_by_id = build_adjacency(edges)

        if adjacency.any? { |_, es| es.size > 2 }
          raise ArgumentError,
                'Selected edges branch at a shared point. Select a single, ' \
                'non-branching Edge chain.'
        end

        endpoint_ids = adjacency.select { |_, es| es.size == 1 }.keys

        if endpoint_ids.empty?
          raise ArgumentError,
                'Selected edges form a closed loop. Closed loops are not ' \
                'supported yet; select an open Edge chain with two distinct ends.'
        end

        unless endpoint_ids.size == 2
          raise ArgumentError,
                'Selected edges do not form a single connected path. Select ' \
                'one continuous Edge chain.'
        end

        traverse(edges, adjacency, vertex_by_id[endpoint_ids.first])
      end

      # Sample a validated OrderedPath at a fixed pitch.
      #
      # All length arguments are SketchUp Length values (internal inches).
      # Raises ArgumentError with a user friendly message on invalid input so
      # the caller can show it directly in a message box.
      def self.sample_path(ordered_path, pitch, start_offset, end_offset)
        raise ArgumentError, 'Pitch must be greater than 0.' if pitch <= 0

        if start_offset.negative? || end_offset.negative?
          raise ArgumentError, 'Start offset and end offset cannot be negative.'
        end

        segments     = build_segments(ordered_path)
        total_length = segments.sum { |s| s[:length] }

        raise ArgumentError, 'The selected path has zero length.' if total_length <= 0

        first_dist = start_offset
        last_dist  = total_length - end_offset

        if first_dist > last_dist
          raise ArgumentError,
                'No room to place components. Reduce the start/end offsets or ' \
                'check the pitch against the path length.'
        end

        points   = []
        tangents = []
        distance = first_dist
        while distance <= last_dist + EPSILON
          index, local_distance = locate_segment(segments, distance)
          segment = segments[index]
          points   << segment[:start_point].offset(segment[:direction], local_distance)
          tangents << segment[:direction]
          distance += pitch
        end

        raise ArgumentError, 'No placement points were generated.' if points.empty?

        Result.new(points, tangents, total_length)
      end

      # --- internals -----------------------------------------------------

      # Build a vertex-id -> incident-edges map (the "degree" of each vertex
      # within the selection) plus a vertex-id -> Vertex lookup.
      def self.build_adjacency(edges)
        adjacency    = Hash.new { |h, k| h[k] = [] }
        vertex_by_id = {}

        edges.each do |edge|
          [edge.start, edge.end].each do |vertex|
            vertex_by_id[vertex.entityID] = vertex
            adjacency[vertex.entityID] << edge
          end
        end

        [adjacency, vertex_by_id]
      end
      private_class_method :build_adjacency

      # Walk the chain from a degree-1 start vertex, following unvisited edges
      # one at a time. With branching already ruled out, each vertex has at
      # most one unvisited incident edge, so this always yields a simple path.
      def self.traverse(edges, adjacency, start_vertex)
        ordered_edges    = []
        ordered_vertices = [start_vertex]
        visited          = {}
        current_vertex   = start_vertex

        until visited.size == edges.size
          candidates = adjacency[current_vertex.entityID].reject { |e| visited[e.entityID] }
          if candidates.empty?
            raise ArgumentError,
                  'Selected edges do not form a single connected path. Select ' \
                  'one continuous Edge chain.'
          end

          edge = candidates.first
          visited[edge.entityID] = true
          ordered_edges << edge

          next_vertex = edge.start.entityID == current_vertex.entityID ? edge.end : edge.start
          ordered_vertices << next_vertex
          current_vertex = next_vertex
        end

        OrderedPath.new(ordered_edges, ordered_vertices)
      end
      private_class_method :traverse

      # Turn an OrderedPath into per-edge segments with a start point,
      # direction and length, in traversal order.
      def self.build_segments(ordered_path)
        ordered_path.edges.each_with_index.map do |_edge, i|
          start_point = ordered_path.vertices[i].position
          end_point   = ordered_path.vertices[i + 1].position
          vector      = end_point - start_point
          length      = vector.length

          raise ArgumentError, 'One of the selected edges has zero length.' if length <= 0

          { start_point: start_point, direction: vector.normalize, length: length }
        end
      end
      private_class_method :build_segments

      # Find the segment that a cumulative distance along the path falls on,
      # and the local distance to travel from that segment's start point.
      # Returns [segment_index, local_distance].
      def self.locate_segment(segments, distance)
        cumulative = 0
        segments.each_with_index do |segment, index|
          segment_end = cumulative + segment[:length]
          if distance <= segment_end + EPSILON || index == segments.size - 1
            local = distance - cumulative
            local = 0 if local.negative?
            local = segment[:length] if local > segment[:length]
            return [index, local]
          end
          cumulative = segment_end
        end
      end
      private_class_method :locate_segment
    end
  end
end

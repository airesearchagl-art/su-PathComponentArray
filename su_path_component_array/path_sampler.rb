# frozen_string_literal: true

module AiResearchAGL
  module PathComponentArray
    # PathSampler turns one or more connected Edges into an ordered list of
    # placement points (with a tangent direction each) spaced at a fixed pitch.
    #
    # v0.2 supports a single Edge or a continuous chain of Edges (a polyline).
    # Branching, disconnected selections, and closed loops are rejected with a
    # friendly ArgumentError. Curves and gradual angle changes are still
    # future work.
    #
    # Two spacing modes are supported when sampling:
    #   :cumulative - pitch is measured along the whole path's cumulative
    #                 length (start_offset / end_offset apply to the whole path)
    #   :per_edge   - pitch resets to 0 at the start of every edge
    #                 (start_offset / end_offset apply to each edge individually)
    #
    # v0.3 adds a pitch mode, independent of spacing_mode:
    #   :fixed  - every step advances by exactly `pitch` (v0.1/v0.2 behavior)
    #   :random - each step advances by `pitch` randomized within
    #             +/- random_ratio, reproducible via `seed`. A single Random
    #             instance is used for the whole path regardless of
    #             spacing_mode, so :per_edge does not restart the sequence.
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
      # Raises ArgumentError with a user friendly (Japanese) message for:
      #   - edges that branch at a shared vertex
      #   - edges that form a closed loop (unsupported in v0.2)
      #   - edges that do not form a single continuous chain
      def self.order_edges(edges)
        edges = edges.uniq
        raise ArgumentError, 'パスに使用するEdgeを1本以上選択してください。' if edges.empty?

        return OrderedPath.new(edges, [edges.first.start, edges.first.end]) if edges.size == 1

        adjacency, vertex_by_id = build_adjacency(edges)

        if adjacency.any? { |_, es| es.size > 2 }
          raise ArgumentError,
                '分岐しているパスはv0.2では未対応です。分岐のない1本のPolylineを' \
                '選択してください。'
        end

        endpoint_ids = adjacency.select { |_, es| es.size == 1 }.keys

        if endpoint_ids.empty?
          raise ArgumentError,
                '閉じたループはv0.2では未対応です。始点と終点が分かれるPolylineを' \
                '選択してください。'
        end

        unless endpoint_ids.size == 2
          raise ArgumentError,
                'パス用Edgeが連続していません。端点同士がつながったEdgeだけを' \
                '選択してください。'
        end

        traverse(edges, adjacency, vertex_by_id[endpoint_ids.first])
      end

      # Random ratio may not reach or exceed 1.0 (100%): the step would drop
      # to zero or go negative and the placement loop could never finish.
      MAX_RANDOM_RATIO = 0.95

      # Sample a validated OrderedPath at a fixed pitch.
      #
      # All length arguments are SketchUp Length values (internal inches).
      # spacing_mode is :cumulative (default) or :per_edge.
      # pitch_mode is :fixed (default) or :random.
      # random_ratio is a fraction (0.2 == 20%), only used when pitch_mode is
      # :random. seed is an Integer, only used when pitch_mode is :random; the
      # same seed always reproduces the same placement.
      # Raises ArgumentError with a user friendly (Japanese) message on
      # invalid input so the caller can show it directly in a message box.
      def self.sample_path(ordered_path, pitch, start_offset, end_offset,
                            spacing_mode = :cumulative, pitch_mode = :fixed,
                            random_ratio = 0.0, seed = 0)
        raise ArgumentError, 'ピッチは0より大きい値を入力してください。' if pitch <= 0

        if start_offset.negative? || end_offset.negative?
          raise ArgumentError, '開始オフセットと終了オフセットは0以上の値を入力してください。'
        end

        rng = nil
        if pitch_mode == :random
          unless random_ratio.is_a?(Numeric) && random_ratio >= 0 && random_ratio <= MAX_RANDOM_RATIO
            raise ArgumentError, 'ランダム率は0以上95以下の数値を入力してください。'
          end
          raise ArgumentError, 'seedは整数で入力してください。' unless seed.is_a?(Integer)

          rng = Random.new(seed)
        end

        segments = build_segments(ordered_path)

        result =
          if spacing_mode == :per_edge
            sample_per_edge(segments, pitch, start_offset, end_offset, pitch_mode, rng, random_ratio)
          else
            sample_cumulative(segments, pitch, start_offset, end_offset, pitch_mode, rng, random_ratio)
          end

        raise ArgumentError, '開始オフセットと終了オフセットにより、有効な配置範囲がありません。' if result.points.empty?

        result
      end

      # --- internals -----------------------------------------------------

      # :cumulative mode: pitch is measured along the whole path. offsets
      # apply to the path as a whole.
      def self.sample_cumulative(segments, pitch, start_offset, end_offset, pitch_mode, rng, random_ratio)
        total_length = segments.sum { |s| s[:length] }
        raise ArgumentError, '選択したパスの長さが0です。' if total_length <= 0

        first_dist = start_offset
        last_dist  = total_length - end_offset

        points   = []
        tangents = []

        if first_dist <= last_dist
          distance = first_dist
          while distance <= last_dist + EPSILON
            index, local_distance = locate_segment(segments, distance)
            segment = segments[index]
            points   << segment[:start_point].offset(segment[:direction], local_distance)
            tangents << segment[:direction]
            distance += next_step(pitch, pitch_mode, rng, random_ratio)
          end
        end

        Result.new(points, tangents, total_length)
      end
      private_class_method :sample_cumulative

      # :per_edge mode: pitch resets to 0 at the start of every edge, and
      # offsets apply to each edge individually. An edge shorter than
      # start_offset + end_offset simply gets no placement points on it.
      #
      # Note: because each edge is sampled independently, a point at the very
      # end of one edge and a point at the very start of the next edge can
      # both land on (or very near) their shared vertex. This is expected in
      # :per_edge mode and is not de-duplicated; see the README for details.
      #
      # When pitch_mode is :random, the same `rng` is drawn from continuously
      # across all edges (it is not reset per edge), so a single seed governs
      # the whole path even though the placement distance itself resets.
      def self.sample_per_edge(segments, pitch, start_offset, end_offset, pitch_mode, rng, random_ratio)
        total_length = segments.sum { |s| s[:length] }
        raise ArgumentError, '選択したパスの長さが0です。' if total_length <= 0

        points   = []
        tangents = []

        segments.each do |segment|
          first_dist = start_offset
          last_dist  = segment[:length] - end_offset
          next if first_dist > last_dist

          distance = first_dist
          while distance <= last_dist + EPSILON
            points   << segment[:start_point].offset(segment[:direction], distance)
            tangents << segment[:direction]
            distance += next_step(pitch, pitch_mode, rng, random_ratio)
          end
        end

        Result.new(points, tangents, total_length)
      end
      private_class_method :sample_per_edge

      # Advance by exactly `pitch` in :fixed mode. In :random mode, advance by
      # `pitch` randomized within +/- random_ratio (e.g. random_ratio 0.2 means
      # each step is between pitch * 0.8 and pitch * 1.2).
      def self.next_step(pitch, pitch_mode, rng, random_ratio)
        return pitch unless pitch_mode == :random

        factor = 1.0 + ((rng.rand * 2.0 - 1.0) * random_ratio)
        pitch * factor
      end
      private_class_method :next_step

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
                  'パス用Edgeが連続していません。端点同士がつながったEdgeだけを' \
                  '選択してください。'
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

          raise ArgumentError, '選択したEdgeの中に、長さが0のEdgeが含まれています。' if length <= 0

          { start_point: start_point, direction: vector.normalize, length: length }
        end
      end
      private_class_method :build_segments

      # Find the segment that a cumulative distance along the path falls on,
      # and the local distance to travel from that segment's start point.
      # Returns [segment_index, local_distance]. Used by :cumulative mode only.
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

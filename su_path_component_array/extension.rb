# frozen_string_literal: true

require 'sketchup.rb'

module AiResearchAGL
  module PathComponentArray
    DIR = File.dirname(__FILE__).freeze

    require File.join(DIR, 'version.rb')
    require File.join(DIR, 'path_sampler.rb')
    require File.join(DIR, 'instance_placer.rb')

    # Entry point wired to the menu item. Validates the selection, asks for
    # settings, then places the array inside a single undo-able operation.
    def self.run
      model     = Sketchup.active_model
      selection = model.selection

      instances = selection.grep(Sketchup::ComponentInstance)
      edges     = selection.grep(Sketchup::Edge)

      unless instances.size == 1 && edges.size >= 1
        UI.messagebox(
          "Select exactly one ComponentInstance and one or more path Edges, " \
          "then run the command again.\n" \
          "ComponentInstanceを1つ、Path用Edgeを1本以上選択してから実行してください。"
        )
        return
      end

      source     = instances.first
      definition = source.definition

      inputs = prompt_inputs
      return if inputs.nil? # user cancelled

      begin
        ordered_path = PathSampler.order_edges(edges)
        sample = PathSampler.sample_path(
          ordered_path, inputs[:pitch], inputs[:start_offset], inputs[:end_offset]
        )
      rescue ArgumentError => e
        UI.messagebox(e.message)
        return
      end

      place_array(model, definition, source, sample, inputs)
    end

    # Run the placement inside start_operation / commit_operation so the whole
    # array is a single Undo step. Roll back on any error.
    def self.place_array(model, definition, source, sample, inputs)
      model.start_operation('Create Path Component Array', true)

      target =
        if inputs[:group_result]
          model.active_entities.add_group.entities
        else
          model.active_entities
        end

      placed = InstancePlacer.place(
        target, definition, source.transformation,
        sample.points, sample.tangents,
        inputs[:follow_path], inputs[:angle_offset_deg]
      )

      model.commit_operation
      UI.messagebox("Placed #{placed.size} component(s) along the edge.")
    rescue StandardError => e
      model.abort_operation
      UI.messagebox("Failed to create the array:\n#{e.message}")
    end

    # Collect settings through UI.inputbox. Returns a Hash, or nil if the user
    # cancelled or entered values that could not be parsed.
    def self.prompt_inputs
      prompts  = ['Pitch', 'Start offset', 'End offset',
                  'Follow path', 'Angle offset (degrees)', 'Group result']
      defaults = ['500mm', '0mm', '0mm', 'Yes', '0.0', 'Yes']
      lists    = ['', '', '', 'Yes|No', '', 'Yes|No']

      results = UI.inputbox(prompts, defaults, lists, 'Create Path Component Array')
      return nil unless results # false when the dialog is cancelled

      begin
        pitch        = results[0].to_l
        start_offset = results[1].to_l
        end_offset   = results[2].to_l
      rescue ArgumentError
        UI.messagebox(
          'Could not read the pitch / offset values. Enter lengths such as ' \
          '500 or 500mm.'
        )
        return nil
      end

      {
        pitch:            pitch,
        start_offset:     start_offset,
        end_offset:       end_offset,
        follow_path:      results[3] == 'Yes',
        angle_offset_deg: results[4].to_f,
        group_result:     results[5] == 'Yes'
      }
    end

    # Build the menu once. SketchUp's "Plugins" menu key maps to the menu shown
    # as "Extensions" in SketchUp 2025.
    unless defined?(@menu_loaded) && @menu_loaded
      submenu = UI.menu('Plugins').add_submenu('su-PathComponentArray')
      submenu.add_item('Create Path Component Array') { run }
      @menu_loaded = true
    end
  end
end

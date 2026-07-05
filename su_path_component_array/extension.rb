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
          'ComponentInstanceを1つ、パス用Edgeを1本以上選択してから実行してください。'
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
          ordered_path, inputs[:pitch], inputs[:start_offset], inputs[:end_offset],
          inputs[:spacing_mode], inputs[:pitch_mode], inputs[:random_ratio], inputs[:seed]
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
      UI.messagebox(completion_message(placed.size, inputs))
    rescue StandardError => e
      model.abort_operation
      UI.messagebox("配置に失敗しました:\n#{e.message}")
    end

    # Build the completion message, including the pitch mode (and seed, when
    # relevant) so the result can be traced back to how it was generated.
    def self.completion_message(count, inputs)
      lines = [
        'パスに沿ってコンポーネントを配置しました。',
        "配置数: #{count}個",
        "ピッチモード: #{inputs[:pitch_mode] == :random ? PITCH_MODE_RANDOM : PITCH_MODE_FIXED}"
      ]
      lines << "seed: #{inputs[:seed]}" if inputs[:pitch_mode] == :random
      lines.join("\n")
    end

    SPACING_MODE_CUMULATIVE = '全体累積長'
    SPACING_MODE_PER_EDGE   = 'Edgeごとリセット'
    PITCH_MODE_FIXED        = '等間隔'
    PITCH_MODE_RANDOM       = 'ランダム'

    # Collect settings through UI.inputbox. Returns a Hash, or nil if the user
    # cancelled or entered values that could not be parsed.
    def self.prompt_inputs
      prompts  = ['ピッチ', '開始オフセット', '終了オフセット', 'パス方向に追従',
                  '追加角度（度）', '結果をグループ化', 'ピッチ方式', 'ピッチモード',
                  'ランダム率（%）', 'seed']
      defaults = ['500mm', '0mm', '0mm', 'はい', '0.0', 'はい', SPACING_MODE_CUMULATIVE,
                  PITCH_MODE_FIXED, '0', '0']
      lists    = ['', '', '', 'はい|いいえ', '', 'はい|いいえ',
                  "#{SPACING_MODE_CUMULATIVE}|#{SPACING_MODE_PER_EDGE}",
                  "#{PITCH_MODE_FIXED}|#{PITCH_MODE_RANDOM}", '', '']

      results = UI.inputbox(prompts, defaults, lists, 'パスコンポーネント配列の作成')
      return nil unless results # false when the dialog is cancelled

      begin
        pitch        = results[0].to_l
        start_offset = results[1].to_l
        end_offset   = results[2].to_l
      rescue ArgumentError
        UI.messagebox(
          'ピッチ・オフセットの値を読み取れませんでした。500 や 500mm のような' \
          '長さを入力してください。'
        )
        return nil
      end

      random_ratio_text = results[8].to_s.strip
      random_ratio_percent =
        begin
          random_ratio_text.empty? ? 0.0 : Float(random_ratio_text)
        rescue ArgumentError, TypeError
          UI.messagebox('ランダム率（%）には数値を入力してください。')
          return nil
        end

      seed_text = results[9].to_s.strip
      seed =
        begin
          seed_text.empty? ? 0 : Integer(seed_text)
        rescue ArgumentError, TypeError
          UI.messagebox('seedは整数で入力してください。')
          return nil
        end

      {
        pitch:            pitch,
        start_offset:     start_offset,
        end_offset:       end_offset,
        follow_path:      results[3] == 'はい',
        angle_offset_deg: results[4].to_f,
        group_result:     results[5] == 'はい',
        spacing_mode:     results[6] == SPACING_MODE_PER_EDGE ? :per_edge : :cumulative,
        pitch_mode:       results[7] == PITCH_MODE_RANDOM ? :random : :fixed,
        random_ratio:     random_ratio_percent / 100.0,
        seed:             seed
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

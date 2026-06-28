# frozen_string_literal: true

# su-PathComponentArray
# SketchUp Ruby Extension loader.
#
# This file lives directly in the SketchUp "Plugins" folder (or is symlinked
# there). SketchUp loads every *.rb file in that folder at startup, so this
# loader only registers the SketchupExtension. The real implementation lives in
# the sibling "su_path_component_array" folder and is loaded on demand.

require 'sketchup.rb'
require 'extensions.rb'

module AiResearchAGL
  module PathComponentArray
    PLUGIN_ROOT = File.dirname(__FILE__).freeze
    PLUGIN_DIR  = File.join(PLUGIN_ROOT, 'su_path_component_array').freeze

    # Version metadata is tiny and safe to load eagerly so we can describe the
    # extension before its main code is required.
    require File.join(PLUGIN_DIR, 'version.rb')

    unless defined?(@extension_registered) && @extension_registered
      extension = SketchupExtension.new(
        'su-PathComponentArray',
        File.join(PLUGIN_DIR, 'extension.rb')
      )
      extension.version     = VERSION
      extension.creator     = 'airesearchagl-art'
      extension.copyright   = "(c) #{Time.now.year} airesearchagl-art"
      extension.description  =
        'Array a selected component along a selected edge at a fixed pitch.'

      Sketchup.register_extension(extension, true)
      @extension_registered = true
    end
  end
end

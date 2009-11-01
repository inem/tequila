#-*- coding: utf-8 -*-

require 'treetop'
require 'tequila'
require 'preprocessor'
require 'tree'

module ActionView
  module TemplateHandlers
    class TequilaJazzHandler < TemplateHandler
      include Compilable

      def compile(template)
        <<CODE
        controller.response.content_type ||= Mime:JSON
        src = TequilaPreprocessor.run("#{template.source}")
        self.output_buffer = TequilaParser.new.parse(src).eval(binding).build_hash.to_json
CODE
      end
    end
  end
end


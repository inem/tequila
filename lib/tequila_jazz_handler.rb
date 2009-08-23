#-*- coding: utf-8 -*-

require 'treetop'
require 'tequila'
require 'tree'

class TequilaJazzHandler < ActionView::TemplateHandler
  # get view object ready to execute template code
  def prepare_view(local_assigns)
    @view.instance_eval do
      # inject assigns into instance variables
      assigns.each do |key, value|
        instance_variable_set "@#{key}", value
      end
      # inject local assigns into reader methods
      local_assigns.each do |key, value|
        class << self; self; end.send(:define_method, key) { value }
      end
    end
    def @view.get_binding
      binding
    end
    @view.get_binding
  end
  def initialize(view)
    @view = view
  end
  def render(template, local_assigns = {})
    src = TequilaPreprocessor.run(template.source)
    parser = TequilaParser.new
    tree = parser.parse(src).eval(prepare_view(local_assigns))
    tree.build_hash.to_json
  end
end

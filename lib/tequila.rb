dir = File.dirname(__FILE__)
$LOAD_PATH.unshift dir unless $LOAD_PATH.include?(dir)

require 'treetop'
require 'tequila_grammar'
require 'preprocessor'
require 'tree'

if defined?(ActionView)
  require 'tequila_jazz_handler'
end

module Tequila
  def render_file filename, locals = { }
    # some code here
  end

  def render templates, locals = { }
    # some code here
  end

end

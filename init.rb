require 'ostruct'
require 'treetop'
require 'tequila_jazz_handler'
ActionView::Template.register_template_handler :jazz, ActionView::TemplateHandlers::TequilaJazzHandler
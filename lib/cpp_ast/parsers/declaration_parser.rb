# frozen_string_literal: true

require_relative 'namespace_parser'
require_relative 'class_parser'
require_relative 'enum_parser'
require_relative 'using_parser'
require_relative 'template_parser'
require_relative 'variable_parser'
require_relative 'function_parser'

module CppAst
  module Parsers
    module DeclarationParser
      include NamespaceParser
      include ClassParser
      include EnumParser
      include UsingParser
      include TemplateParser
      include VariableParser
      include FunctionParser
    end
  end
end

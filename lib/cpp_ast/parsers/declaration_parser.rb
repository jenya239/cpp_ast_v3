# frozen_string_literal: true

require_relative 'declaration/namespace'
require_relative 'declaration/class'
require_relative 'declaration/enum'
require_relative 'declaration/using'
require_relative 'declaration/template'
require_relative 'declaration/variable'
require_relative 'declaration/function'

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

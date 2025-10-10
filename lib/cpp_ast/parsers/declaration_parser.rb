# frozen_string_literal: true

module CppAst
  module Parsers
    # DeclarationParser - module with declaration parsing methods
    # Handles: namespace, class, struct, function, variable, using, enum, template
    #
    # This module contains all declaration parsing logic.
    # It is included in StatementParser to modularize the codebase.
    #
    # Methods:
    #   - parse_namespace_declaration
    #   - parse_class_declaration
    #   - parse_struct_declaration
    #   - parse_function_declaration
    #   - parse_variable_declaration
    #   - parse_using_declaration
    #   - parse_enum_declaration
    #   - parse_template_declaration
    #   - looks_like_declaration?
    #   - looks_like_function_declaration?
    module DeclarationParser
      # Note: All methods are in statement_parser.rb for now
      # Future refactoring can move them here
    end
  end
end


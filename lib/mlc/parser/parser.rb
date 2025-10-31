# frozen_string_literal: true

require_relative "lexer"
require_relative "../ast/nodes"
require_relative "base_parser"
require_relative "expression_parser"
require_relative "pattern_parser"
require_relative "type_parser"
require_relative "statement_parser"
require_relative "declaration_parser"

module MLC
  module Parser
    class Parser
      # Include all parser modules
      include BaseParser
      include ExpressionParser
      include PatternParser
      include TypeParser
      include StatementParser
      include DeclarationParser

      def initialize(source, filename: nil)
        initialize_parser(source, filename: filename)
      end

      def parse
        parse_program
      end
    end
  end
end

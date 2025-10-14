# frozen_string_literal: true

require_relative "cpp_ast/lexer/token"
require_relative "cpp_ast/lexer/lexer"
require_relative "cpp_ast/nodes/base"
require_relative "cpp_ast/nodes/expressions"
require_relative "cpp_ast/nodes/statements"
require_relative "cpp_ast/nodes/ownership_nodes"
require_relative "cpp_ast/nodes/result_nodes"
require_relative "cpp_ast/nodes/sum_type_nodes"
require_relative "cpp_ast/nodes/match_nodes"
require_relative "cpp_ast/parsers/base_parser"
require_relative "cpp_ast/parsers/type_parser"
require_relative "cpp_ast/parsers/control_flow_parser"
require_relative "cpp_ast/parsers/declaration_parser"
require_relative "cpp_ast/parsers/expression_parser"
require_relative "cpp_ast/parsers/statement_parser"
require_relative "cpp_ast/parsers/program_parser"
require_relative "cpp_ast/builder/dsl"
require_relative "cpp_ast/builder/fluent"
require_relative "cpp_ast/builder/dsl_generator"

module CppAst
  class ParseError < StandardError; end
  
  class << self
    # Public API: Parse source into AST
    def parse(source)
      lexer = Lexer.new(source)
      parser = Parsers::ProgramParser.new(lexer)
      parser.parse
    end
    
    # Public API: Generate DSL code from AST
    def to_dsl(ast, indent: "  ")
      generator = Builder::DSLGenerator.new(indent: indent)
      generator.generate(ast)
    end
  end
end


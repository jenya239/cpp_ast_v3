# frozen_string_literal: true

require_relative "cpp_ast/lexer/token"
require_relative "cpp_ast/lexer/lexer"
require_relative "cpp_ast/nodes/base"
require_relative "cpp_ast/nodes/expressions"
require_relative "cpp_ast/nodes/statements"
require_relative "cpp_ast/nodes/parameter"
require_relative "cpp_ast/nodes/modifiers"
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
require_relative "cpp_ast/builder/formatting_context"
require_relative "cpp_ast/builder/dsl"
require_relative "cpp_ast/builder/fluent"
require_relative "cpp_ast/builder/dsl_generator"
require_relative "cpp_ast/builder/dsl_v2_simple"

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
    def to_dsl(ast, indent: "  ", mode: :lossless)
      generator = Builder::DSLGenerator.new(indent: indent, mode: mode)
      generator.generate(ast)
    end
    
    # Get current formatting mode
    def formatting_mode
      Thread.current[:cpp_ast_formatting_mode] || :pretty
    end
    
    # Set formatting mode for current thread
    def formatting_mode=(mode)
      unless [:pretty, :lossless].include?(mode)
        raise ArgumentError, "Invalid mode: #{mode}. Use :pretty or :lossless"
      end
      Thread.current[:cpp_ast_formatting_mode] = mode
    end
    
    # Execute block with specific formatting mode
    def with_formatting_mode(mode)
      old_mode = Thread.current[:cpp_ast_formatting_mode]
      Thread.current[:cpp_ast_formatting_mode] = mode
      yield
    ensure
      Thread.current[:cpp_ast_formatting_mode] = old_mode
    end
  end
end


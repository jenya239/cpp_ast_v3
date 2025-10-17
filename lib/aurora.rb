# frozen_string_literal: true

require_relative "aurora/ast/nodes"
require_relative "aurora/core_ir/nodes"
require_relative "aurora/core_ir/builder"
require_relative "aurora/parser/lexer"
require_relative "aurora/parser/parser"
require_relative "aurora/passes/to_core"
require_relative "aurora/backend/cpp_lowering"
require_relative "aurora/backend/header_generator"

module Aurora
  class ParseError < StandardError; end
  class CompileError < StandardError; end
  
  class << self
    # Main entry point: Parse Aurora source and return C++ AST
    def compile(source)
      # 1. Parse Aurora source
      ast = parse(source)
      
      # 2. Transform to CoreIR
      core_ir = transform_to_core(ast)
      
      # 3. Lower to C++ AST
      cpp_ast = lower_to_cpp(core_ir)
      
      cpp_ast
    end
    
    # Parse Aurora source to AST
    def parse(source)
      parser = Parser::Parser.new(source)
      parser.parse
    rescue => e
      raise ParseError, "Parse error: #{e.message}"
    end
    
    # Transform Aurora AST to CoreIR
    def transform_to_core(ast)
      transformer = Passes::ToCore.new
      transformer.transform(ast)
    rescue => e
      raise CompileError, "Transform error: #{e.message}"
    end
    
    # Lower CoreIR to C++ AST
    def lower_to_cpp(core_ir)
      lowerer = Backend::CppLowering.new
      lowerer.lower(core_ir)
    rescue => e
      raise CompileError, "Lowering error: #{e.message}"
    end
    
    # Full pipeline: Aurora source -> C++ source
    def to_cpp(source)
      cpp_ast = compile(source)
      cpp_ast.to_source
    end

    # Generate header and implementation files for a module
    # Returns: { header: String, implementation: String }
    def to_hpp_cpp(source)
      # Parse and transform to CoreIR
      ast = parse(source)
      core_ir = transform_to_core(ast)

      # Generate header and implementation
      lowering = Backend::CppLowering.new
      generator = Backend::HeaderGenerator.new(lowering)
      generator.generate(core_ir)
    rescue => e
      raise CompileError, "Header generation error: #{e.message}\n#{e.backtrace.join("\n")}"
    end
  end
end

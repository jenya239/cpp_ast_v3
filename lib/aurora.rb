# frozen_string_literal: true

require_relative "aurora/ast/nodes"
require_relative "aurora/core_ir/nodes"
require_relative "aurora/core_ir/builder"
require_relative "aurora/parser/lexer"
require_relative "aurora/parser/parser"
require_relative "aurora/passes/to_core"
require_relative "aurora/backend/cpp_lowering"
require_relative "aurora/backend/header_generator"
require_relative "aurora/stdlib_resolver"

module Aurora
  class ParseError < StandardError; end

  class CompileError < StandardError
    attr_reader :origin

    def initialize(message = nil, origin: nil)
      super(message)
      @origin = origin
    end

    def message
      base = super
      origin_label = origin&.label
      origin_label ? "#{origin_label}: #{base}" : base
    end

    def full_message(highlight: true, order: :top, trace: nil)
      origin_label = origin&.label
      base = super(highlight: highlight, order: order, trace: trace)
      text = origin_label ? "#{origin_label}: #{base}" : base
      highlight ? text : text
    end
  end
  
  class << self
    # Main entry point: Parse Aurora source and return C++ AST
    def compile(source, filename: nil)
      # 1. Parse Aurora source
      ast = parse(source, filename: filename)
      
      # 2. Transform to CoreIR
      core_ir = transform_to_core(ast)
      
      # 3. Lower to C++ AST
      cpp_ast = lower_to_cpp(core_ir)
      
      cpp_ast
    end
    
    # Parse Aurora source to AST
    def parse(source, filename: nil)
      parser = Parser::Parser.new(source, filename: filename)
      parser.parse
    rescue => e
      raise ParseError, "Parse error: #{e.message}"
    end
    
    # Transform Aurora AST to CoreIR
    def transform_to_core(ast)
      transformer = Passes::ToCore.new
      transformer.transform(ast)
    rescue CompileError
      raise
    rescue => e
      origin = e.respond_to?(:origin) ? e.origin : nil
      raise CompileError.new("Transform error: #{e.message}", origin: origin)
    end
    
    # Lower CoreIR to C++ AST
    def lower_to_cpp(core_ir)
      lowerer = Backend::CppLowering.new
      lowerer.lower(core_ir)
    rescue CompileError
      raise
    rescue => e
      origin = e.respond_to?(:origin) ? e.origin : nil
      raise CompileError.new("Lowering error: #{e.message}", origin: origin)
    end
    
    # Full pipeline: Aurora source -> C++ source
    def to_cpp(source, filename: nil)
      cpp_ast = compile(source, filename: filename)
      cpp_ast.to_source
    end

    # Generate header and implementation files for a module
    # Returns: { header: String, implementation: String }
    def to_hpp_cpp(source, filename: nil)
      # Parse and transform to CoreIR
      ast = parse(source, filename: filename)
      core_ir = transform_to_core(ast)

      # Generate header and implementation
      lowering = Backend::CppLowering.new
      generator = Backend::HeaderGenerator.new(lowering)
      generator.generate(core_ir)
    rescue CompileError
      raise
    rescue => e
      origin = e.respond_to?(:origin) ? e.origin : nil
      message = "Header generation error: #{e.message}\n#{e.backtrace.join("\n")}"
      raise CompileError.new(message, origin: origin)
    end
  end
end

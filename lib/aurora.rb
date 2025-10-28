# frozen_string_literal: true

require_relative "aurora/ast/nodes"
require_relative "aurora/core_ir/nodes"
require_relative "aurora/core_ir/builder"
require_relative "aurora/event_bus"
require_relative "aurora/diagnostics/event_logger"
require_relative "aurora/application"
require_relative "aurora/parser/lexer"
require_relative "aurora/parser/parser"
require_relative "aurora/passes/to_core"
require_relative "aurora/backend/cpp_lowering"
require_relative "aurora/backend/header_generator"
require_relative "aurora/stdlib_resolver"
require_relative "aurora/stdlib_scanner"
require_relative "aurora/stdlib_signature_registry"
require_relative "aurora/function_registry"

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

      # 2. Build application context
      app = Application.new
      stdlib_scanner = StdlibScanner.new
      to_core = app.build_to_core

      # 3. Transform to CoreIR (with type_registry)
      core_ir, type_registry, function_registry = transform_to_core_with_registry(ast, transformer: to_core)

      # 4. Lower to C++ AST (with shared type_registry and stdlib_scanner)
      cpp_lowerer = app.build_cpp_lowering(type_registry: type_registry, function_registry: function_registry, stdlib_scanner: stdlib_scanner)
      cpp_ast = cpp_lowerer.lower(core_ir)

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
    # For backward compatibility, returns just core_ir
    # Use transform_to_core_with_registry if you need the type_registry
    def transform_to_core(ast)
      core_ir, _type_registry = transform_to_core_with_registry(ast)
      core_ir
    end

    # Transform Aurora AST to CoreIR (with TypeRegistry)
    # Returns: [core_ir, type_registry]
    def transform_to_core_with_registry(ast, transformer: Passes::ToCore.new)
      core_ir = transformer.transform(ast)
      [core_ir, transformer.type_registry, transformer.function_registry]
    rescue CompileError
      raise
    rescue => e
      origin = e.respond_to?(:origin) ? e.origin : nil
      raise CompileError.new("Transform error: #{e.message}", origin: origin)
    end

    # Lower CoreIR to C++ AST
    # @param core_ir [CoreIR::Module] CoreIR module
    # @param type_registry [TypeRegistry] Shared type registry from ToCore
    # @param stdlib_scanner [StdlibScanner] Scanner for automatic stdlib function resolution
    def lower_to_cpp(core_ir, type_registry: nil, function_registry: nil, stdlib_scanner: nil, event_bus: nil)
      lowerer = Backend::CppLowering.new(
        type_registry: type_registry,
        function_registry: function_registry,
        stdlib_scanner: stdlib_scanner,
        event_bus: event_bus
      )
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
      core_ir, type_registry, function_registry = transform_to_core_with_registry(ast)

      # Create StdlibScanner
      stdlib_scanner = StdlibScanner.new

      # Generate header and implementation
      lowering = Backend::CppLowering.new(type_registry: type_registry, function_registry: function_registry, stdlib_scanner: stdlib_scanner)
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

# frozen_string_literal: true

require_relative "mlc/ast/nodes"
require_relative "mlc/high_ir/nodes"
require_relative "mlc/high_ir/builder"
require_relative "mlc/event_bus"
require_relative "mlc/diagnostics/event_logger"
require_relative "mlc/application"
require_relative "mlc/parser/lexer"
require_relative "mlc/parser/parser"
require_relative "mlc/irgen"
require_relative "mlc/backend/codegen"
require_relative "mlc/backend/header_generator"
require_relative "mlc/stdlib_resolver"
require_relative "mlc/stdlib_scanner"
require_relative "mlc/stdlib_signature_registry"
require_relative "mlc/function_registry"

module MLC
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
    def compile(source, filename: nil, runtime_policy: nil)
      # 1. Parse Aurora source
      ast = parse(source, filename: filename)

      # 2. Build application context
      app = Application.new
      stdlib_scanner = StdlibScanner.new
      to_core = app.build_to_core

      # 3. Transform to HighIR (with type_registry)
      core_ir, type_registry, function_registry = transform_to_core_with_registry(ast, transformer: to_core)

      # 4. Lower to C++ AST (with shared type_registry and stdlib_scanner)
      cpp_lowerer = app.build_cpp_lowering(
        type_registry: type_registry,
        function_registry: function_registry,
        stdlib_scanner: stdlib_scanner,
        runtime_policy: runtime_policy
      )
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
    
    # Transform Aurora AST to HighIR
    # For backward compatibility, returns just core_ir
    # Use transform_to_core_with_registry if you need the type_registry
    def transform_to_core(ast)
      core_ir, _type_registry = transform_to_core_with_registry(ast)
      core_ir
    end

    # Transform Aurora AST to HighIR (with TypeRegistry)
    # Returns: [core_ir, type_registry]
    def transform_to_core_with_registry(ast, transformer: IRGen.new)
      core_ir = transformer.transform(ast)
      [core_ir, transformer.type_registry, transformer.function_registry]
    rescue CompileError
      raise
    rescue => e
      origin = e.respond_to?(:origin) ? e.origin : nil
      raise CompileError.new("Transform error: #{e.message}", origin: origin)
    end

    # Lower HighIR to C++ AST
    # @param core_ir [HighIR::Module] HighIR module
    # @param type_registry [TypeRegistry] Shared type registry from ToCore
    # @param stdlib_scanner [StdlibScanner] Scanner for automatic stdlib function resolution
    # @param runtime_policy [Backend::RuntimePolicy] Policy for choosing lowering strategies
    def lower_to_cpp(core_ir, type_registry: nil, function_registry: nil, stdlib_scanner: nil, event_bus: nil, runtime_policy: nil)
      lowerer = Backend::CodeGen.new(
        type_registry: type_registry,
        function_registry: function_registry,
        stdlib_scanner: stdlib_scanner,
        event_bus: event_bus,
        runtime_policy: runtime_policy
      )
      lowerer.lower(core_ir)
    rescue CompileError
      raise
    rescue => e
      origin = e.respond_to?(:origin) ? e.origin : nil
      raise CompileError.new("Lowering error: #{e.message}", origin: origin)
    end
    
    # Full pipeline: Aurora source -> C++ source
    def to_cpp(source, filename: nil, runtime_policy: nil)
      cpp_ast = compile(source, filename: filename, runtime_policy: runtime_policy)
      cpp_ast.to_source
    end

    # Generate header and implementation files for a module
    # Returns: { header: String, implementation: String }
    def to_hpp_cpp(source, filename: nil, runtime_policy: nil)
      # Parse and transform to HighIR
      ast = parse(source, filename: filename)
      core_ir, type_registry, function_registry = transform_to_core_with_registry(ast)

      # Create StdlibScanner
      stdlib_scanner = StdlibScanner.new

      # Generate header and implementation
      lowering = Backend::CodeGen.new(
        type_registry: type_registry,
        function_registry: function_registry,
        stdlib_scanner: stdlib_scanner,
        runtime_policy: runtime_policy
      )
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

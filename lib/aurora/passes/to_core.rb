# frozen_string_literal: true

require_relative "../ast/nodes"
require_relative "../core_ir/nodes"
require_relative "../core_ir/builder"
require_relative "../event_bus"
require_relative "../stdlib_resolver"
require_relative "../stdlib_signature_registry"
require_relative "../type_registry"
require_relative "to_core/base_transformer"
require_relative "to_core/type_context"
require_relative "pass_manager"
require_relative "../rules/rule_engine"
require_relative "../rules/core_ir/sum_constructor_rule"
require_relative "../rules/core_ir/match_rule"
require_relative "../rules/core_ir/function_effect_rule"
require_relative "../rules/core_ir/stdlib_import_rule"
require_relative "../type_system/type_constraint_solver"
require_relative "../type_system/generic_call_resolver"
require_relative "../type_system/match_analyzer"
require_relative "../type_system/effect_analyzer"
require_relative "to_core/type_inference"
require_relative "to_core/expression_transformer"
require_relative "to_core/statement_transformer"
require_relative "to_core/function_transformer"

module Aurora
  module Passes
    class ToCore
      # Include all transformation modules
      include BaseTransformer
      include TypeInference
      include ExpressionTransformer
      include StatementTransformer
      include FunctionTransformer

      FunctionInfo = Struct.new(:name, :param_types, :ret_type, :type_params) do
        def initialize(name, param_types, ret_type, type_params = [])
          super(name, param_types, ret_type, type_params)
        end
      end
      NUMERIC_PRIMITIVES = %w[i32 f32 i64 f64 u32 u64].freeze
      IO_RETURN_TYPES = {
        "print" => "i32",
        "println" => "i32",
        "eprint" => "i32",
        "eprintln" => "i32",
        "read_line" => "string",
        "input" => "string",
        "args" => :array_of_string,
        "to_string" => "string",
        "format" => "string"
      }.freeze
      BUILTIN_CONSTRAINTS = {
        "Numeric" => %w[i32 f32 i64 f64 u32 u64]
      }.freeze

      # Expose type_registry for sharing with CppLowering
      attr_reader :type_registry, :rule_engine, :generic_call_resolver, :match_analyzer, :effect_analyzer, :stdlib_registry, :event_bus

      def initialize(rule_engine: nil, generic_call_resolver: nil, type_constraint_solver: nil, match_analyzer: nil, effect_analyzer: nil, event_bus: nil)
        # NEW: Unified type registry
        @type_registry = TypeRegistry.new
        @rule_engine = rule_engine || build_default_rule_engine
        @type_context = TypeContext.new
        @type_constraint_solver = type_constraint_solver
        @generic_call_resolver = generic_call_resolver
        @match_analyzer = match_analyzer
        @effect_analyzer = effect_analyzer
        @stdlib_resolver = StdlibResolver.new
        @stdlib_registry = StdlibSignatureRegistry.new(scanner: @stdlib_resolver.scanner)
        @event_bus = event_bus || Aurora::EventBus.new

        # OLD: Keep for backward compatibility during migration
        @type_table = {}
        @function_table = {}
        @type_decl_table = {}
        @sum_type_constructors = {}
        @var_types = {}  # Track variable types for let bindings
        @temp_counter = 0
        @loop_depth = 0
        @lambda_param_type_stack = @type_context.lambda_param_stack
        @function_return_type_stack = @type_context.function_return_stack
        @current_node = nil

        @type_constraint_solver ||= TypeSystem::TypeConstraintSolver.new(
          infer_type_arguments: method(:infer_type_arguments),
          substitute_type: method(:substitute_type),
          ensure_compatible_type: method(:ensure_compatible_type),
          type_error: ->(message) { type_error(message) }
        )

        @generic_call_resolver ||= TypeSystem::GenericCallResolver.new(
          constraint_solver: @type_constraint_solver
        )

        @match_analyzer ||= TypeSystem::MatchAnalyzer.new(
          ensure_compatible_type: method(:ensure_compatible_type)
        )

        @effect_analyzer ||= TypeSystem::EffectAnalyzer.new(
          pure_expression: method(:is_pure_expression)
        )
      end

      def transform(ast)
        case ast
        when AST::Program
          transform_program(ast)
        when AST::FuncDecl
          transform_function(ast)
        when AST::TypeDecl
          transform_type_decl(ast)
        else
          raise "Unknown AST node: #{ast.class}"
        end
      end

      private

      def build_default_rule_engine
        engine = Rules::RuleEngine.new
        engine.register(:core_ir_type_decl, Rules::CoreIR::SumConstructorRule.new)
        engine.register(:core_ir_match_expr, Rules::CoreIR::MatchRule.new)
        engine.register(:core_ir_function, Rules::CoreIR::FunctionEffectRule.new)
        engine.register(:core_ir_stdlib_import, Rules::CoreIR::StdlibImportRule.new)
        engine
      end

      def with_type_params(params, &block)
        @type_context.with_type_params(params, &block)
      end

      def current_type_params
        @type_context.current_type_params
      end

      def with_function_return(type, &block)
        @type_context.with_function_return(type, &block)
      end

      def current_function_return
        @type_context.current_function_return
      end

      def with_lambda_param_types(types, &block)
        @type_context.with_lambda_param_types(types, &block)
      end

      def current_lambda_param_types
        @type_context.current_lambda_param_types
      end
    end
  end
end

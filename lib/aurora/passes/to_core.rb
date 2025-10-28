# frozen_string_literal: true

require_relative "../ast/nodes"
require_relative "../core_ir/nodes"
require_relative "../core_ir/builder"
require_relative "../event_bus"
require_relative "../stdlib_resolver"
require_relative "../stdlib_signature_registry"
require_relative "../function_registry"
require_relative "../type_registry"
require_relative "to_core/base_transformer"
require_relative "to_core/type_context"
require_relative "pass_manager"
require_relative "../rules/rule_engine"
require_relative "../rules/core_ir/sum_constructor_rule"
require_relative "../rules/core_ir/match_rule"
require_relative "../rules/core_ir/function_effect_rule"
require_relative "../rules/core_ir/stdlib_import_rule"
require_relative "../rules/core_ir/expression/literal_rule"
require_relative "../rules/core_ir/expression/var_ref_rule"
require_relative "../rules/core_ir/expression/member_rule"
require_relative "../rules/core_ir/expression/call_rule"
require_relative "../rules/core_ir/expression/unary_rule"
require_relative "../rules/core_ir/expression/binary_rule"
require_relative "../rules/core_ir/expression/pipe_rule"
require_relative "../rules/core_ir/expression/let_rule"
require_relative "../rules/core_ir/expression/record_literal_rule"
require_relative "../rules/core_ir/expression/if_rule"
require_relative "../rules/core_ir/expression/array_literal_rule"
require_relative "../rules/core_ir/expression/do_rule"
require_relative "../rules/core_ir/expression/block_rule"
require_relative "../rules/core_ir/expression/match_rule"
require_relative "../rules/core_ir/expression/lambda_rule"
require_relative "../rules/core_ir/expression/index_access_rule"
require_relative "../rules/core_ir/expression/for_loop_rule"
require_relative "../rules/core_ir/expression/while_loop_rule"
require_relative "../rules/core_ir/expression/list_comprehension_rule"
require_relative "../rules/core_ir/statement/expr_stmt_rule"
require_relative "../rules/core_ir/statement/variable_decl_rule"
require_relative "../rules/core_ir/statement/assignment_rule"
require_relative "../rules/core_ir/statement/for_rule"
require_relative "../rules/core_ir/statement/if_rule"
require_relative "../rules/core_ir/statement/while_rule"
require_relative "../rules/core_ir/statement/return_rule"
require_relative "../rules/core_ir/statement/break_rule"
require_relative "../rules/core_ir/statement/continue_rule"
require_relative "../rules/core_ir/statement/block_rule"
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
      attr_reader :type_registry, :function_registry, :rule_engine, :generic_call_resolver, :match_analyzer, :effect_analyzer, :stdlib_registry, :event_bus

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

        @function_registry = FunctionRegistry.new
        @type_decl_table = {}
        @sum_type_constructors = {}
        @var_types = {}  # Track variable types for let bindings
        @temp_counter = 0
        @loop_depth = 0
        @lambda_param_type_stack = @type_context.lambda_param_stack
        @function_return_type_stack = @type_context.function_return_stack
        @current_node = nil
        @current_import_aliases = nil
        @current_module_name = nil
        @current_module_namespace = nil

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

        ensure_required_rules!
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
        engine.register(:core_ir_expression, Rules::CoreIR::Expression::LiteralRule.new)
        engine.register(:core_ir_expression, Rules::CoreIR::Expression::VarRefRule.new)
        engine.register(:core_ir_expression, Rules::CoreIR::Expression::MemberRule.new)
        engine.register(:core_ir_expression, Rules::CoreIR::Expression::CallRule.new)
        engine.register(:core_ir_expression, Rules::CoreIR::Expression::UnaryRule.new)
        engine.register(:core_ir_expression, Rules::CoreIR::Expression::PipeRule.new)
        engine.register(:core_ir_expression, Rules::CoreIR::Expression::BinaryRule.new)
        engine.register(:core_ir_expression, Rules::CoreIR::Expression::LetRule.new)
        engine.register(:core_ir_expression, Rules::CoreIR::Expression::RecordLiteralRule.new)
        engine.register(:core_ir_expression, Rules::CoreIR::Expression::IfRule.new)
        engine.register(:core_ir_expression, Rules::CoreIR::Expression::ArrayLiteralRule.new)
        engine.register(:core_ir_expression, Rules::CoreIR::Expression::DoRule.new)
        engine.register(:core_ir_expression, Rules::CoreIR::Expression::BlockRule.new)
        engine.register(:core_ir_expression, Rules::CoreIR::Expression::MatchRule.new)
        engine.register(:core_ir_expression, Rules::CoreIR::Expression::LambdaRule.new)
        engine.register(:core_ir_expression, Rules::CoreIR::Expression::IndexAccessRule.new)
        engine.register(:core_ir_expression, Rules::CoreIR::Expression::ForLoopRule.new)
        engine.register(:core_ir_expression, Rules::CoreIR::Expression::WhileLoopRule.new)
        engine.register(:core_ir_expression, Rules::CoreIR::Expression::ListComprehensionRule.new)
        engine.register(:core_ir_statement, Rules::CoreIR::Statement::ExprStmtRule.new)
        engine.register(:core_ir_statement, Rules::CoreIR::Statement::VariableDeclRule.new)
        engine.register(:core_ir_statement, Rules::CoreIR::Statement::AssignmentRule.new)
        engine.register(:core_ir_statement, Rules::CoreIR::Statement::ForRule.new)
        engine.register(:core_ir_statement, Rules::CoreIR::Statement::IfRule.new)
        engine.register(:core_ir_statement, Rules::CoreIR::Statement::WhileRule.new)
        engine.register(:core_ir_statement, Rules::CoreIR::Statement::ReturnRule.new)
        engine.register(:core_ir_statement, Rules::CoreIR::Statement::BreakRule.new)
        engine.register(:core_ir_statement, Rules::CoreIR::Statement::ContinueRule.new)
        engine.register(:core_ir_statement, Rules::CoreIR::Statement::BlockRule.new)
        engine
      end

      def ensure_required_rules!
        ensure_rule_registered(:core_ir_type_decl, Rules::CoreIR::SumConstructorRule)
        ensure_rule_registered(:core_ir_match_expr, Rules::CoreIR::MatchRule)
        ensure_rule_registered(:core_ir_function, Rules::CoreIR::FunctionEffectRule)
        ensure_rule_registered(:core_ir_stdlib_import, Rules::CoreIR::StdlibImportRule)
        ensure_rule_registered(:core_ir_expression, Rules::CoreIR::Expression::LiteralRule)
        ensure_rule_registered(:core_ir_expression, Rules::CoreIR::Expression::VarRefRule)
        ensure_rule_registered(:core_ir_expression, Rules::CoreIR::Expression::MemberRule)
        ensure_rule_registered(:core_ir_expression, Rules::CoreIR::Expression::CallRule)
        ensure_rule_registered(:core_ir_expression, Rules::CoreIR::Expression::UnaryRule)
        ensure_rule_registered(:core_ir_expression, Rules::CoreIR::Expression::PipeRule)
        ensure_rule_registered(:core_ir_expression, Rules::CoreIR::Expression::BinaryRule)
        ensure_rule_registered(:core_ir_expression, Rules::CoreIR::Expression::LetRule)
        ensure_rule_registered(:core_ir_expression, Rules::CoreIR::Expression::RecordLiteralRule)
        ensure_rule_registered(:core_ir_expression, Rules::CoreIR::Expression::IfRule)
        ensure_rule_registered(:core_ir_expression, Rules::CoreIR::Expression::ArrayLiteralRule)
        ensure_rule_registered(:core_ir_expression, Rules::CoreIR::Expression::DoRule)
        ensure_rule_registered(:core_ir_expression, Rules::CoreIR::Expression::BlockRule)
        ensure_rule_registered(:core_ir_expression, Rules::CoreIR::Expression::MatchRule)
        ensure_rule_registered(:core_ir_expression, Rules::CoreIR::Expression::LambdaRule)
        ensure_rule_registered(:core_ir_expression, Rules::CoreIR::Expression::IndexAccessRule)
        ensure_rule_registered(:core_ir_expression, Rules::CoreIR::Expression::ForLoopRule)
        ensure_rule_registered(:core_ir_expression, Rules::CoreIR::Expression::WhileLoopRule)
        ensure_rule_registered(:core_ir_expression, Rules::CoreIR::Expression::ListComprehensionRule)
        ensure_rule_registered(:core_ir_statement, Rules::CoreIR::Statement::ExprStmtRule)
        ensure_rule_registered(:core_ir_statement, Rules::CoreIR::Statement::VariableDeclRule)
        ensure_rule_registered(:core_ir_statement, Rules::CoreIR::Statement::AssignmentRule)
        ensure_rule_registered(:core_ir_statement, Rules::CoreIR::Statement::ForRule)
        ensure_rule_registered(:core_ir_statement, Rules::CoreIR::Statement::IfRule)
        ensure_rule_registered(:core_ir_statement, Rules::CoreIR::Statement::WhileRule)
        ensure_rule_registered(:core_ir_statement, Rules::CoreIR::Statement::ReturnRule)
        ensure_rule_registered(:core_ir_statement, Rules::CoreIR::Statement::BreakRule)
        ensure_rule_registered(:core_ir_statement, Rules::CoreIR::Statement::ContinueRule)
        ensure_rule_registered(:core_ir_statement, Rules::CoreIR::Statement::BlockRule)
      end

      def ensure_rule_registered(stage, rule_class)
        rules = @rule_engine.registry[stage.to_sym]
        return if rules.any? { |rule| rule.is_a?(rule_class) || rule == rule_class || rule.class == rule_class }

        @rule_engine.register(stage, rule_class.new)
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

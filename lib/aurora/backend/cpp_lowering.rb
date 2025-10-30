# frozen_string_literal: true

require_relative "../../cpp_ast"
require_relative "../core_ir/nodes"
require_relative "../rules/rule_engine"
require_relative "../type_registry"
require_relative "cpp_lowering/base_lowerer"
require_relative "cpp_lowering/expression_lowerer"
require_relative "cpp_lowering/statement_lowerer"
require_relative "cpp_lowering/type_lowerer"
require_relative "cpp_lowering/function_lowerer"
require_relative "cpp_lowering/rules/function_rule"
require_relative "runtime_policy"
require_relative "block_complexity_analyzer"
require_relative "../rules/cpp/cpp_expression_rule"
require_relative "../rules/cpp/expression/literal_rule"
require_relative "../rules/cpp/expression/var_ref_rule"
require_relative "../rules/cpp/expression/binary_rule"
require_relative "../rules/cpp/expression/unary_rule"
require_relative "../rules/cpp/expression/call_rule"
require_relative "../rules/cpp/expression/regex_rule"
require_relative "../rules/cpp/expression/member_rule"
require_relative "../rules/cpp/expression/index_rule"
require_relative "../rules/cpp/expression/array_literal_rule"
require_relative "../rules/cpp/expression/record_rule"
require_relative "../rules/cpp/expression/if_rule"
require_relative "../rules/cpp/expression/block_rule"
require_relative "../rules/cpp/expression/lambda_rule"
require_relative "../rules/cpp/expression/match_rule"
require_relative "../rules/cpp/expression/list_comp_rule"
require_relative "../rules/cpp/cpp_statement_rule"
require_relative "../rules/cpp/statement/expr_statement_rule"
require_relative "../rules/cpp/statement/variable_decl_rule"
require_relative "../rules/cpp/statement/assignment_rule"
require_relative "../rules/cpp/statement/return_rule"
require_relative "../rules/cpp/statement/break_rule"
require_relative "../rules/cpp/statement/continue_rule"
require_relative "../rules/cpp/statement/if_rule"
require_relative "../rules/cpp/statement/while_rule"
require_relative "../rules/cpp/statement/for_rule"
require_relative "../rules/cpp/statement/match_rule"

module Aurora
  module Backend
    # Simple variable representation for range-based for loops
    ForLoopVariable = Struct.new(:type_str, :name) do
      def to_source
        "#{type_str} #{name}"
      end
    end

    class CppLowering
      # Include all lowering modules
      include BaseLowerer
      include ExpressionLowerer
      include StatementLowerer
      include TypeLowerer
      include FunctionLowerer

      IO_FUNCTIONS = {
        "print" => "aurora::io::print",
        "println" => "aurora::io::println",
        "eprint" => "aurora::io::eprint",
        "eprintln" => "aurora::io::eprintln",
        "read_line" => "aurora::io::read_line",
        "input" => "aurora::io::read_all",
        "args" => "aurora::io::args",
        "to_string" => "aurora::to_string",
        "format" => "aurora::format"
      }.freeze

      # Stdlib function overrides that need special lowering behavior
      STDLIB_FUNCTION_OVERRIDES = {
        "to_f32" => "static_cast<float>"
      }.freeze

      attr_reader :rule_engine, :event_bus, :function_registry, :type_registry, :runtime_policy

      def initialize(type_registry: nil, function_registry: nil, stdlib_scanner: nil, rule_engine: nil, event_bus: nil, runtime_policy: nil)
        # NEW: Use shared TypeRegistry if provided
        @type_registry = type_registry
        @function_registry = function_registry
        @type_map = {
          "i8" => "int8_t",
          "u8" => "uint8_t",
          "i16" => "int16_t",
          "u16" => "uint16_t",
          "i32" => "int",
          "u32" => "uint32_t",
          "i64" => "int64_t",
          "u64" => "uint64_t",
          "usize" => "size_t",
          "f32" => "float",
          "f64" => "double",
          "bool" => "bool",
          "void" => "void",
          "str" => "aurora::String",
          "string" => "aurora::String",
          "regex" => "aurora::Regex"
        }

        # NEW: Use StdlibScanner for automatic function name resolution
        @stdlib_scanner = stdlib_scanner

        @rule_engine = rule_engine || build_default_rule_engine
        @event_bus = event_bus || Aurora::EventBus.new

        # NEW: Runtime policy for lowering strategies
        @runtime_policy = runtime_policy || RuntimePolicy.new
      end

      def lower(core_ir)
        case core_ir
        when CoreIR::Module
          lower_module(core_ir)
        when CoreIR::Func
          lower_function(core_ir)
        when CoreIR::TypeDecl
          lower_type_decl(core_ir)
        else
          raise "Unknown CoreIR node: #{core_ir.class}"
        end
      end

      private

      def build_default_rule_engine
        engine = Aurora::Rules::RuleEngine.new
        # Function-level rules
        engine.register(:cpp_function_declaration, Aurora::Backend::CppLowering::Rules::FunctionRule.new)

        # C++ expression lowering rules (all 15 expression types)
        engine.register(:cpp_expression, Aurora::Rules::Cpp::Expression::LiteralRule.new)
        engine.register(:cpp_expression, Aurora::Rules::Cpp::Expression::VarRefRule.new)
        engine.register(:cpp_expression, Aurora::Rules::Cpp::Expression::BinaryRule.new)
        engine.register(:cpp_expression, Aurora::Rules::Cpp::Expression::UnaryRule.new)
        engine.register(:cpp_expression, Aurora::Rules::Cpp::Expression::CallRule.new)
        engine.register(:cpp_expression, Aurora::Rules::Cpp::Expression::RegexRule.new)
        engine.register(:cpp_expression, Aurora::Rules::Cpp::Expression::MemberRule.new)
        engine.register(:cpp_expression, Aurora::Rules::Cpp::Expression::IndexRule.new)
        engine.register(:cpp_expression, Aurora::Rules::Cpp::Expression::ArrayLiteralRule.new)
        engine.register(:cpp_expression, Aurora::Rules::Cpp::Expression::RecordRule.new)
        engine.register(:cpp_expression, Aurora::Rules::Cpp::Expression::IfRule.new)
        engine.register(:cpp_expression, Aurora::Rules::Cpp::Expression::BlockRule.new)
        engine.register(:cpp_expression, Aurora::Rules::Cpp::Expression::LambdaRule.new)
        engine.register(:cpp_expression, Aurora::Rules::Cpp::Expression::MatchRule.new)
        engine.register(:cpp_expression, Aurora::Rules::Cpp::Expression::ListCompRule.new)

        # C++ statement lowering rules (all 10 statement types)
        engine.register(:cpp_statement, Aurora::Rules::Cpp::Statement::ExprStatementRule.new)
        engine.register(:cpp_statement, Aurora::Rules::Cpp::Statement::VariableDeclRule.new)
        engine.register(:cpp_statement, Aurora::Rules::Cpp::Statement::AssignmentRule.new)
        engine.register(:cpp_statement, Aurora::Rules::Cpp::Statement::ReturnRule.new)
        engine.register(:cpp_statement, Aurora::Rules::Cpp::Statement::BreakRule.new)
        engine.register(:cpp_statement, Aurora::Rules::Cpp::Statement::ContinueRule.new)
        engine.register(:cpp_statement, Aurora::Rules::Cpp::Statement::IfRule.new)
        engine.register(:cpp_statement, Aurora::Rules::Cpp::Statement::WhileRule.new)
        engine.register(:cpp_statement, Aurora::Rules::Cpp::Statement::ForRule.new)
        engine.register(:cpp_statement, Aurora::Rules::Cpp::Statement::MatchRule.new)

        engine
      end
    end
  end
end

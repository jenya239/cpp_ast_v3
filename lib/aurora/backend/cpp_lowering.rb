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
require_relative "../rules/codegen/cpp_expression_rule"
require_relative "../rules/codegen/expression/literal_rule"
require_relative "../rules/codegen/expression/var_ref_rule"
require_relative "../rules/codegen/expression/binary_rule"
require_relative "../rules/codegen/expression/unary_rule"
require_relative "../rules/codegen/expression/call_rule"
require_relative "../rules/codegen/expression/regex_rule"
require_relative "../rules/codegen/expression/member_rule"
require_relative "../rules/codegen/expression/index_rule"
require_relative "../rules/codegen/expression/array_literal_rule"
require_relative "../rules/codegen/expression/record_rule"
require_relative "../rules/codegen/expression/if_rule"
require_relative "../rules/codegen/expression/block_rule"
require_relative "../rules/codegen/expression/lambda_rule"
require_relative "../rules/codegen/expression/match_rule"
require_relative "../rules/codegen/expression/list_comp_rule"
require_relative "../rules/codegen/cpp_statement_rule"
require_relative "../rules/codegen/statement/expr_statement_rule"
require_relative "../rules/codegen/statement/variable_decl_rule"
require_relative "../rules/codegen/statement/assignment_rule"
require_relative "../rules/codegen/statement/return_rule"
require_relative "../rules/codegen/statement/break_rule"
require_relative "../rules/codegen/statement/continue_rule"
require_relative "../rules/codegen/statement/if_rule"
require_relative "../rules/codegen/statement/while_rule"
require_relative "../rules/codegen/statement/for_rule"
require_relative "../rules/codegen/statement/match_rule"

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

      attr_reader :rule_engine, :event_bus, :function_registry, :type_registry, :runtime_policy, :type_map

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

        @rule_engine = rule_engine || Aurora::Rules::RuleEngine.new
        @event_bus = event_bus || Aurora::EventBus.new

        # NEW: Runtime policy for lowering strategies
        @runtime_policy = runtime_policy || RuntimePolicy.new

        # IMPORTANT: Register C++ lowering rules if not already registered
        # (Check if :cpp_expression category has any rules)
        if @rule_engine.registry[:cpp_expression].nil? || @rule_engine.registry[:cpp_expression].empty?
          register_cpp_rules(@rule_engine)
        end
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

      def register_cpp_rules(engine)
        # Function-level rules
        engine.register(:cpp_function_declaration, Aurora::Backend::CppLowering::Rules::FunctionRule.new)

        # C++ expression lowering rules (all 15 expression types)
        engine.register(:cpp_expression, Aurora::Rules::CodeGen::Expression::LiteralRule.new)
        engine.register(:cpp_expression, Aurora::Rules::CodeGen::Expression::VarRefRule.new)
        engine.register(:cpp_expression, Aurora::Rules::CodeGen::Expression::BinaryRule.new)
        engine.register(:cpp_expression, Aurora::Rules::CodeGen::Expression::UnaryRule.new)
        engine.register(:cpp_expression, Aurora::Rules::CodeGen::Expression::CallRule.new)
        engine.register(:cpp_expression, Aurora::Rules::CodeGen::Expression::RegexRule.new)
        engine.register(:cpp_expression, Aurora::Rules::CodeGen::Expression::MemberRule.new)
        engine.register(:cpp_expression, Aurora::Rules::CodeGen::Expression::IndexRule.new)
        engine.register(:cpp_expression, Aurora::Rules::CodeGen::Expression::ArrayLiteralRule.new)
        engine.register(:cpp_expression, Aurora::Rules::CodeGen::Expression::RecordRule.new)
        engine.register(:cpp_expression, Aurora::Rules::CodeGen::Expression::IfRule.new)
        engine.register(:cpp_expression, Aurora::Rules::CodeGen::Expression::BlockRule.new)
        engine.register(:cpp_expression, Aurora::Rules::CodeGen::Expression::LambdaRule.new)
        engine.register(:cpp_expression, Aurora::Rules::CodeGen::Expression::MatchRule.new)
        engine.register(:cpp_expression, Aurora::Rules::CodeGen::Expression::ListCompRule.new)

        # C++ statement lowering rules (all 10 statement types)
        engine.register(:cpp_statement, Aurora::Rules::CodeGen::Statement::ExprStatementRule.new)
        engine.register(:cpp_statement, Aurora::Rules::CodeGen::Statement::VariableDeclRule.new)
        engine.register(:cpp_statement, Aurora::Rules::CodeGen::Statement::AssignmentRule.new)
        engine.register(:cpp_statement, Aurora::Rules::CodeGen::Statement::ReturnRule.new)
        engine.register(:cpp_statement, Aurora::Rules::CodeGen::Statement::BreakRule.new)
        engine.register(:cpp_statement, Aurora::Rules::CodeGen::Statement::ContinueRule.new)
        engine.register(:cpp_statement, Aurora::Rules::CodeGen::Statement::IfRule.new)
        engine.register(:cpp_statement, Aurora::Rules::CodeGen::Statement::WhileRule.new)
        engine.register(:cpp_statement, Aurora::Rules::CodeGen::Statement::ForRule.new)
        engine.register(:cpp_statement, Aurora::Rules::CodeGen::Statement::MatchRule.new)
      end
    end
  end
end

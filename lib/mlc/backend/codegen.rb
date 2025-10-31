# frozen_string_literal: true

require_relative "../../cpp_ast"
require_relative "../high_ir/nodes"
require_relative "../rules/rule_engine"
require_relative "../type_registry"
require_relative "codegen/base_lowerer"
require_relative "codegen/expression_lowerer"
require_relative "codegen/statement_lowerer"
require_relative "codegen/type_lowerer"
require_relative "codegen/function_lowerer"
require_relative "codegen/rules/function_rule"
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

module MLC
  module Backend
    # Simple variable representation for range-based for loops
    ForLoopVariable = Struct.new(:type_str, :name) do
      def to_source
        "#{type_str} #{name}"
      end
    end

    class CodeGen
      # Include all lowering modules
      include BaseLowerer
      include ExpressionLowerer
      include StatementLowerer
      include TypeLowerer
      include FunctionLowerer

      IO_FUNCTIONS = {
        "print" => "mlc::io::print",
        "println" => "mlc::io::println",
        "eprint" => "mlc::io::eprint",
        "eprintln" => "mlc::io::eprintln",
        "read_line" => "mlc::io::read_line",
        "input" => "mlc::io::read_all",
        "args" => "mlc::io::args",
        "to_string" => "mlc::to_string",
        "format" => "mlc::format"
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
          "str" => "mlc::String",
          "string" => "mlc::String",
          "regex" => "mlc::Regex"
        }

        # NEW: Use StdlibScanner for automatic function name resolution
        @stdlib_scanner = stdlib_scanner

        @rule_engine = rule_engine || MLC::Rules::RuleEngine.new
        @event_bus = event_bus || MLC::EventBus.new

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
        when HighIR::Module
          lower_module(core_ir)
        when HighIR::Func
          lower_function(core_ir)
        when HighIR::TypeDecl
          lower_type_decl(core_ir)
        else
          raise "Unknown HighIR node: #{core_ir.class}"
        end
      end

      private

      def register_cpp_rules(engine)
        # Function-level rules
        engine.register(:cpp_function_declaration, MLC::Backend::CodeGen::Rules::FunctionRule.new)

        # C++ expression lowering rules (all 15 expression types)
        engine.register(:cpp_expression, MLC::Rules::CodeGen::Expression::LiteralRule.new)
        engine.register(:cpp_expression, MLC::Rules::CodeGen::Expression::VarRefRule.new)
        engine.register(:cpp_expression, MLC::Rules::CodeGen::Expression::BinaryRule.new)
        engine.register(:cpp_expression, MLC::Rules::CodeGen::Expression::UnaryRule.new)
        engine.register(:cpp_expression, MLC::Rules::CodeGen::Expression::CallRule.new)
        engine.register(:cpp_expression, MLC::Rules::CodeGen::Expression::RegexRule.new)
        engine.register(:cpp_expression, MLC::Rules::CodeGen::Expression::MemberRule.new)
        engine.register(:cpp_expression, MLC::Rules::CodeGen::Expression::IndexRule.new)
        engine.register(:cpp_expression, MLC::Rules::CodeGen::Expression::ArrayLiteralRule.new)
        engine.register(:cpp_expression, MLC::Rules::CodeGen::Expression::RecordRule.new)
        engine.register(:cpp_expression, MLC::Rules::CodeGen::Expression::IfRule.new)
        engine.register(:cpp_expression, MLC::Rules::CodeGen::Expression::BlockRule.new)
        engine.register(:cpp_expression, MLC::Rules::CodeGen::Expression::LambdaRule.new)
        engine.register(:cpp_expression, MLC::Rules::CodeGen::Expression::MatchRule.new)
        engine.register(:cpp_expression, MLC::Rules::CodeGen::Expression::ListCompRule.new)

        # C++ statement lowering rules (all 10 statement types)
        engine.register(:cpp_statement, MLC::Rules::CodeGen::Statement::ExprStatementRule.new)
        engine.register(:cpp_statement, MLC::Rules::CodeGen::Statement::VariableDeclRule.new)
        engine.register(:cpp_statement, MLC::Rules::CodeGen::Statement::AssignmentRule.new)
        engine.register(:cpp_statement, MLC::Rules::CodeGen::Statement::ReturnRule.new)
        engine.register(:cpp_statement, MLC::Rules::CodeGen::Statement::BreakRule.new)
        engine.register(:cpp_statement, MLC::Rules::CodeGen::Statement::ContinueRule.new)
        engine.register(:cpp_statement, MLC::Rules::CodeGen::Statement::IfRule.new)
        engine.register(:cpp_statement, MLC::Rules::CodeGen::Statement::WhileRule.new)
        engine.register(:cpp_statement, MLC::Rules::CodeGen::Statement::ForRule.new)
        engine.register(:cpp_statement, MLC::Rules::CodeGen::Statement::MatchRule.new)
      end
    end
  end
end

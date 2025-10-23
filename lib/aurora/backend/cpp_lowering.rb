# frozen_string_literal: true

require_relative "../../cpp_ast"
require_relative "../core_ir/nodes"
require_relative "cpp_lowering/base_lowerer"
require_relative "cpp_lowering/expression_lowerer"
require_relative "cpp_lowering/statement_lowerer"
require_relative "cpp_lowering/type_lowerer"
require_relative "cpp_lowering/function_lowerer"

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

      def initialize
        @type_map = {
          "i32" => "int",
          "f32" => "float",
          "bool" => "bool",
          "void" => "void",
          "str" => "aurora::String",
          "string" => "aurora::String",
          "regex" => "aurora::Regex"
        }
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
    end
  end
end

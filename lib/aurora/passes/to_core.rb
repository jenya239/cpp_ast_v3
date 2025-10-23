# frozen_string_literal: true

require_relative "../ast/nodes"
require_relative "../core_ir/nodes"
require_relative "../core_ir/builder"
require_relative "../stdlib_resolver"
require_relative "to_core/base_transformer"
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

      FunctionInfo = Struct.new(:name, :param_types, :ret_type)
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

      def initialize
        @type_table = {}
        @function_table = {}
        @type_decl_table = {}
        @sum_type_constructors = {}
        @var_types = {}  # Track variable types for let bindings
        @temp_counter = 0
        @loop_depth = 0
        @lambda_param_type_stack = []
        @function_return_type_stack = []
        @current_node = nil
        @current_type_params = []  # Track type parameters of current function/type
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
    end
  end
end

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

      # Stdlib functions with their qualified C++ names
      STDLIB_FUNCTIONS = {
        # Array module (aurora::collections namespace)
        "sum_i32" => "aurora::collections::sum_i32",
        "sum_f32" => "aurora::collections::sum_f32",
        "min_i32" => "aurora::collections::min_i32",
        "max_i32" => "aurora::collections::max_i32",
        "min_f32" => "aurora::collections::min_f32",
        "max_f32" => "aurora::collections::max_f32",
        "contains_i32" => "aurora::collections::contains_i32",
        "contains_f32" => "aurora::collections::contains_f32",
        "contains_str" => "aurora::collections::contains_str",
        "reverse_i32" => "aurora::collections::reverse_i32",
        "reverse_f32" => "aurora::collections::reverse_f32",
        "reverse_str" => "aurora::collections::reverse_str",
        "take_i32" => "aurora::collections::take_i32",
        "take_f32" => "aurora::collections::take_f32",
        "take_str" => "aurora::collections::take_str",
        "drop_i32" => "aurora::collections::drop_i32",
        "drop_f32" => "aurora::collections::drop_f32",
        "drop_str" => "aurora::collections::drop_str",
        "slice_i32" => "aurora::collections::slice_i32",
        "slice_f32" => "aurora::collections::slice_f32",
        "slice_str" => "aurora::collections::slice_str",
        "range" => "aurora::collections::range",
        "join_strings" => "aurora::collections::join_strings",

        # Math module (aurora::math namespace)
        "abs" => "aurora::math::abs",
        "abs_f" => "aurora::math::abs_f",
        "min" => "aurora::math::min",
        "max" => "aurora::math::max",
        "min_f" => "aurora::math::min_f",
        "max_f" => "aurora::math::max_f",
        "pow_f" => "aurora::math::pow_f",
        "sqrt_f" => "aurora::math::sqrt_f",
        "sin_f" => "aurora::math::sin_f",
        "cos_f" => "aurora::math::cos_f",
        "tan_f" => "aurora::math::tan_f",

        # Conv module (aurora namespace - in aurora_string.hpp)
        "parse_i32" => "aurora::parse_i32",
        "parse_f32" => "aurora::parse_f32",
        "parse_bool" => "aurora::parse_bool",
        "to_string_i32" => "aurora::to_string_i32",
        "to_string_f32" => "aurora::to_string_f32",
        "to_string_bool" => "aurora::to_string_bool",
        "to_f32" => "static_cast<float>",

        # File module (aurora::file namespace)
        "read_to_string" => "aurora::file::read_to_string",
        "read_lines" => "aurora::file::read_lines",
        "write_string" => "aurora::file::write_string",
        "write_lines" => "aurora::file::write_lines",
        "append_string" => "aurora::file::append_string",
        "append_line" => "aurora::file::append_line",
        "exists" => "aurora::file::exists",
        "remove_file" => "aurora::file::remove_file",
        "rename_file" => "aurora::file::rename_file",

        # JSON module (aurora::json namespace)
        "parse_json" => "aurora::json::parse_json",
        "stringify_json" => "aurora::json::stringify_json",
        "stringify_json_pretty" => "aurora::json::stringify_json_pretty",
        "json_null" => "aurora::json::json_null",
        "json_bool" => "aurora::json::json_bool",
        "json_number" => "aurora::json::json_number",
        "json_string" => "aurora::json::json_string",
        "json_array" => "aurora::json::json_array",
        "json_object" => "aurora::json::json_object",
        "json_get" => "aurora::json::json_get",
        "json_set" => "aurora::json::json_set",
        "json_has_key" => "aurora::json::json_has_key",
        "json_keys" => "aurora::json::json_keys",
        "json_array_length" => "aurora::json::json_array_length",
        "json_array_get" => "aurora::json::json_array_get",
        "json_array_push" => "aurora::json::json_array_push",

        # Graphics module (aurora::graphics namespace)
        "create_window" => "aurora::graphics::create_window",
        "flush_window" => "aurora::graphics::flush_window",
        "create_draw_context" => "aurora::graphics::create_draw_context",
        "poll_event" => "aurora::graphics::poll_event",
        "is_quit_event" => "aurora::graphics::is_quit_event",
        "rgb" => "aurora::graphics::rgb",
        "rgba" => "aurora::graphics::rgba",
        "clear" => "aurora::graphics::clear",
        "set_color" => "aurora::graphics::set_color",
        "draw_rect" => "aurora::graphics::draw_rect",
        "stroke_rect" => "aurora::graphics::stroke_rect",
        "draw_circle" => "aurora::graphics::draw_circle",
        "stroke_circle" => "aurora::graphics::stroke_circle",
        "draw_line" => "aurora::graphics::draw_line",
        "draw_text" => "aurora::graphics::draw_text",
        "sleep_ms" => "aurora::graphics::sleep_ms"
      }.freeze

      def initialize(type_registry: nil, stdlib_scanner: nil)
        # NEW: Use shared TypeRegistry if provided
        @type_registry = type_registry

        # NEW: Use StdlibScanner for automatic function name resolution
        @stdlib_scanner = stdlib_scanner

        # OLD: Fallback type_map for backward compatibility
        # Will be deprecated once TypeRegistry is fully integrated
        @type_map = {
          "i32" => "int",
          "f32" => "float",
          "bool" => "bool",
          "void" => "void",
          "str" => "aurora::String",
          "string" => "aurora::String",
          "regex" => "aurora::Regex",
          # Graphics module types (opaque pointer types)
          # TODO: These should come from TypeRegistry
          "Window" => "aurora::graphics::Window*",
          "DrawContext" => "aurora::graphics::DrawContext*",
          "Color" => "aurora::graphics::Color",
          "Event" => "aurora::graphics::Event",
          "EventType" => "aurora::graphics::EventType"
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

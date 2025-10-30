# frozen_string_literal: true

require_relative "../../base_rule"
require_relative "../../../backend/cpp_lowering/helpers"

module Aurora
  module Rules
    module Cpp
      module Expression
        # Rule for lowering CoreIR function call expressions to C++ function calls
        # Handles multiple call types:
        # 1. IO functions (print, println, etc.)
        # 2. Stdlib function overrides (to_f32, etc.)
        # 3. Qualified functions (via function_registry or stdlib_scanner)
        # 4. Array method calls (length, push, map, filter, fold, etc.)
        # 5. Regular function calls
        class CallRule < BaseRule
          include Aurora::Backend::CppLoweringHelpers

          # IO function mappings
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

          # Stdlib function overrides
          STDLIB_FUNCTION_OVERRIDES = {
            "to_f32" => "static_cast<float>"
          }.freeze

          def applies?(node, _context = {})
            node.is_a?(Aurora::CoreIR::CallExpr)
          end

          def apply(node, context = {})
            lowerer = context[:lowerer]
            function_registry = context[:function_registry]

            # Check for IO functions
            if node.callee.is_a?(Aurora::CoreIR::VarExpr) && IO_FUNCTIONS.key?(node.callee.name)
              return lower_io_function(node, lowerer)
            end

            # Check for stdlib overrides
            if node.callee.is_a?(Aurora::CoreIR::VarExpr)
              name = node.callee.name

              if (override_expr = lower_stdlib_override(name, node, lowerer))
                return override_expr
              end

              # Check for qualified function names (from registry or stdlib)
              unless context[:user_functions]&.include?(name)
                qualified_name = qualified_function_name(name, function_registry)
                if qualified_name.nil? && context[:stdlib_scanner]
                  qualified_name = context[:stdlib_scanner].cpp_function_name(name)
                end

                if qualified_name
                  args = node.args.map { |arg| lowerer.send(:lower_expression, arg) }
                  num_separators = [args.size - 1, 0].max
                  return CppAst::Nodes::FunctionCallExpression.new(
                    callee: CppAst::Nodes::Identifier.new(name: qualified_name),
                    arguments: args,
                    argument_separators: Array.new(num_separators, ", ")
                  )
                end
              end
            end

            # Check for array method calls
            if node.callee.is_a?(Aurora::CoreIR::MemberExpr) && node.callee.object.type.is_a?(Aurora::CoreIR::ArrayType)
              return lower_array_method_call(node, lowerer)
            end

            # Regular function call
            callee = lowerer.send(:lower_expression, node.callee)
            args = node.args.map { |arg| lowerer.send(:lower_expression, arg) }
            num_separators = [args.size - 1, 0].max

            CppAst::Nodes::FunctionCallExpression.new(
              callee: callee,
              arguments: args,
              argument_separators: Array.new(num_separators, ", ")
            )
          end

          private

          # Lower IO function calls
          def lower_io_function(call, lowerer)
            target = IO_FUNCTIONS[call.callee.name]
            callee = CppAst::Nodes::Identifier.new(name: target)
            args = call.args.map { |arg| lowerer.send(:lower_expression, arg) }
            num_separators = [args.size - 1, 0].max

            CppAst::Nodes::FunctionCallExpression.new(
              callee: callee,
              arguments: args,
              argument_separators: Array.new(num_separators, ", ")
            )
          end

          # Lower stdlib override functions
          def lower_stdlib_override(name, call, lowerer)
            override = STDLIB_FUNCTION_OVERRIDES[name]
            return nil unless override

            case name
            when "to_f32"
              arg = call.args.first ? lowerer.send(:lower_expression, call.args.first) : CppAst::Nodes::Identifier.new(name: "0")
              CppAst::Nodes::FunctionCallExpression.new(
                callee: CppAst::Nodes::Identifier.new(name: override),
                arguments: [arg],
                argument_separators: []
              )
            else
              nil
            end
          end

          # Lower array method calls (length, push, map, filter, fold, etc.)
          def lower_array_method_call(call, lowerer)
            method_name = call.callee.member
            array_obj = lowerer.send(:lower_expression, call.callee.object)

            case method_name
            when "length"
              # arr.length() -> arr.size()
              member_access = CppAst::Nodes::MemberAccessExpression.new(
                object: array_obj,
                operator: ".",
                member: CppAst::Nodes::Identifier.new(name: "size")
              )
              CppAst::Nodes::FunctionCallExpression.new(
                callee: member_access,
                arguments: [],
                argument_separators: []
              )

            when "is_empty"
              # arr.is_empty() -> arr.empty()
              member_access = CppAst::Nodes::MemberAccessExpression.new(
                object: array_obj,
                operator: ".",
                member: CppAst::Nodes::Identifier.new(name: "empty")
              )
              CppAst::Nodes::FunctionCallExpression.new(
                callee: member_access,
                arguments: [],
                argument_separators: []
              )

            when "push"
              # arr.push(x) -> arr.push_back(x)
              member_access = CppAst::Nodes::MemberAccessExpression.new(
                object: array_obj,
                operator: ".",
                member: CppAst::Nodes::Identifier.new(name: "push_back")
              )
              args = call.args.map { |arg| lowerer.send(:lower_expression, arg) }
              CppAst::Nodes::FunctionCallExpression.new(
                callee: member_access,
                arguments: args,
                argument_separators: Array.new([args.size - 1, 0].max, ", ")
              )

            when "pop"
              # arr.pop() -> arr.pop_back()
              member_access = CppAst::Nodes::MemberAccessExpression.new(
                object: array_obj,
                operator: ".",
                member: CppAst::Nodes::Identifier.new(name: "pop_back")
              )
              CppAst::Nodes::FunctionCallExpression.new(
                callee: member_access,
                arguments: [],
                argument_separators: []
              )

            when "map"
              # arr.map(f) -> aurora::collections::map(arr, f)
              func_arg = call.args.first ? lowerer.send(:lower_expression, call.args.first) : nil
              CppAst::Nodes::FunctionCallExpression.new(
                callee: CppAst::Nodes::Identifier.new(name: "aurora::collections::map"),
                arguments: [array_obj, func_arg].compact,
                argument_separators: func_arg ? [", "] : []
              )

            when "filter"
              # arr.filter(pred) -> aurora::collections::filter(arr, pred)
              predicate = call.args.first ? lowerer.send(:lower_expression, call.args.first) : nil
              CppAst::Nodes::FunctionCallExpression.new(
                callee: CppAst::Nodes::Identifier.new(name: "aurora::collections::filter"),
                arguments: [array_obj, predicate].compact,
                argument_separators: predicate ? [", "] : []
              )

            when "fold"
              # arr.fold(init, f) -> aurora::collections::fold(arr, init, f)
              init_arg = call.args[0] ? lowerer.send(:lower_expression, call.args[0]) : nil
              func_arg = call.args[1] ? lowerer.send(:lower_expression, call.args[1]) : nil
              arguments = [array_obj]
              separators = []
              if init_arg
                arguments << init_arg
                separators << ", "
              end
              if func_arg
                arguments << func_arg
                separators << ", "
              end
              CppAst::Nodes::FunctionCallExpression.new(
                callee: CppAst::Nodes::Identifier.new(name: "aurora::collections::fold"),
                arguments: arguments,
                argument_separators: separators
              )

            else
              # Fallback: call method directly
              member_access = CppAst::Nodes::MemberAccessExpression.new(
                object: array_obj,
                operator: ".",
                member: CppAst::Nodes::Identifier.new(name: method_name)
              )
              args = call.args.map { |arg| lowerer.send(:lower_expression, arg) }
              CppAst::Nodes::FunctionCallExpression.new(
                callee: member_access,
                arguments: args,
                argument_separators: Array.new([args.size - 1, 0].max, ", ")
              )
            end
          end
        end
      end
    end
  end
end

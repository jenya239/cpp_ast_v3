# frozen_string_literal: true

require_relative "../../base_rule"

module Aurora
  module Rules
    module IRGen
      module Statement
        # ReturnRule: Transform AST return statements to CoreIR
        # Contains FULL logic (no delegation to transformer)
        # Validates return type compatibility with function signature
        class ReturnRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(Aurora::AST::Return)
          end

          def apply(node, context = {})
            transformer = context.fetch(:transformer)
            expr_svc = context.fetch(:expression_transformer)
            type_checker = context.fetch(:type_checker)
            context_mgr = context.fetch(:context_manager)

            # Validate: return must be inside function
            expected = context_mgr.current_function_return
            unless expected
              type_checker.type_error("return statement outside of function")
            end

            # Transform return expression (if present)
            expr_ir = node.expr ? expr_svc.transform_expression(node.expr) : nil

            # Validate return type compatibility
            if type_checker.void_type?(expected)
              # Void function: no return value allowed
              if expr_ir
                type_checker.type_error("return value not allowed in void function", node: node)
              end
            else
              # Non-void function: return value required
              unless expr_ir
                expected_name = type_checker.describe_type(expected)
                type_checker.type_error("return statement requires a value of type #{expected_name}", node: node)
              end
              # Check type compatibility
              type_checker.ensure_compatible(expr_ir.type, expected, "return statement", node: node)
            end

            # Build return statement (wrap in array for statement rule convention)
            [Aurora::CoreIR::Builder.return_stmt(expr_ir)]
          end
        end
      end
    end
  end
end

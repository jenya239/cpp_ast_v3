# frozen_string_literal: true

require_relative "../../base_rule"

module MLC
  module Rules
    module IRGen
      module Statement
        # AssignmentRule: Transform AST assignment statements to HighIR
        # Contains FULL logic (no delegation to transformer)
        # Validates target variable exists and value type is compatible
        class AssignmentRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(MLC::AST::Assignment)
          end

          def apply(node, context = {})
            transformer = context.fetch(:transformer)
            expr_svc = context.fetch(:expression_transformer)
            type_checker = context.fetch(:type_checker)

            # Validate: target must be variable reference
            unless node.target.is_a?(MLC::AST::VarRef)
              type_checker.type_error("Assignment target must be a variable", node: node)
            end

            target_name = node.target.name
            var_types = transformer.instance_variable_get(:@var_types)

            # Validate: variable must exist
            existing_type = var_types[target_name]
            unless existing_type
              type_checker.type_error("Assignment to undefined variable '#{target_name}'", node: node)
            end

            # Transform value expression
            value_ir = expr_svc.transform_expression(node.value)

            # Validate: value type must be compatible with variable type
            type_checker.ensure_compatible(value_ir.type, existing_type, "assignment to '#{target_name}'")

            # Update variable type in scope (may refine type)
            var_types[target_name] = existing_type

            # Build assignment statement
            target_ir = MLC::HighIR::Builder.var(target_name, existing_type)
            [MLC::HighIR::Builder.assignment_stmt(target_ir, value_ir)]
          end
        end
      end
    end
  end
end

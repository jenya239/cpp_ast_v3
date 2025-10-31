# frozen_string_literal: true

require_relative "../../base_rule"

module MLC
  module Rules
    module IRGen
      module Statement
        # VariableDeclRule: Transform AST variable declarations to HighIR
        # Contains FULL logic (no delegation to transformer)
        # Handles type inference, explicit type annotations, and record type refinement
        class VariableDeclRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(MLC::AST::VariableDecl)
          end

          def apply(node, context = {})
            transformer = context.fetch(:transformer)
            expr_svc = context.fetch(:expression_transformer)
            type_checker = context.fetch(:type_checker)

            # Transform initialization value
            value_ir = expr_svc.transform_expression(node.value)

            # Determine variable type: explicit annotation or inferred from value
            var_type = if node.type
                         # Explicit type annotation provided
                         explicit_type = type_checker.transform_type(node.type)

                         # Special case: anonymous record with explicit type - refine to named record
                         if value_ir.is_a?(MLC::HighIR::RecordExpr) && value_ir.type_name == "record"
                           actual_type_name = type_checker.type_name(explicit_type)
                           value_ir = MLC::HighIR::Builder.record(actual_type_name, value_ir.fields, explicit_type)
                         else
                           # Validate type compatibility
                           type_checker.ensure_compatible(value_ir.type, explicit_type, "variable '#{node.name}' initialization")
                         end
                         explicit_type
                       else
                         # Infer type from initialization value
                         value_ir.type
                       end

            # Add variable to scope with inferred/explicit type
            var_types = transformer.instance_variable_get(:@var_types)
            var_types[node.name] = var_type

            # Build variable declaration statement
            [MLC::HighIR::Builder.variable_decl_stmt(
              node.name,
              var_type,
              value_ir,
              mutable: node.mutable
            )]
          end
        end
      end
    end
  end
end

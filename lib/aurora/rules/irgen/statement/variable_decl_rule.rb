# frozen_string_literal: true

require_relative "../../base_rule"

module Aurora
  module Rules
    module IRGen
      module Statement
        # VariableDeclRule: Transform AST variable declarations to CoreIR
        # Contains FULL logic (no delegation to transformer)
        # Handles type inference, explicit type annotations, and record type refinement
        class VariableDeclRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(Aurora::AST::VariableDecl)
          end

          def apply(node, context = {})
            transformer = context.fetch(:transformer)

            # Transform initialization value
            value_ir = transformer.send(:transform_expression, node.value)

            # Determine variable type: explicit annotation or inferred from value
            var_type = if node.type
                         # Explicit type annotation provided
                         explicit_type = transformer.send(:transform_type, node.type)

                         # Special case: anonymous record with explicit type - refine to named record
                         if value_ir.is_a?(Aurora::CoreIR::RecordExpr) && value_ir.type_name == "record"
                           actual_type_name = transformer.send(:type_name, explicit_type)
                           value_ir = Aurora::CoreIR::Builder.record(actual_type_name, value_ir.fields, explicit_type)
                         else
                           # Validate type compatibility
                           transformer.send(:ensure_compatible_type, value_ir.type, explicit_type, "variable '#{node.name}' initialization")
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
            [Aurora::CoreIR::Builder.variable_decl_stmt(
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

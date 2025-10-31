# frozen_string_literal: true

require_relative "../../base_rule"

module Aurora
  module Rules
    module IRGen
      module Expression
        # RecordLiteralRule: Transform AST record literals to CoreIR record expressions
        # Contains FULL logic (no delegation to transformer)
        class RecordLiteralRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(Aurora::AST::RecordLit)
          end

          def apply(node, context = {})
            transformer = context.fetch(:transformer)
            expr_svc = context.fetch(:expression_transformer)
            record_builder = context.fetch(:record_builder)

            # Transform all field values recursively
            fields = node.fields.transform_keys { |key| key.to_s }
                              .transform_values { |value| expr_svc.transform_expression(value) }

            # Determine record type based on type_name
            if node.type_name == "record"
              # Anonymous record - infer from context/registry or build anonymous
              record_builder.infer_from_context(fields) ||
                record_builder.infer_from_registry(fields) ||
                record_builder.build_anonymous(fields)
            else
              # Named record - build with explicit type name
              record_builder.build_named(node.type_name, fields)
            end
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

require_relative "../../base_rule"

module Aurora
  module Rules
    module IRGen
      module Expression
        # IndexAccessRule: Transform AST array indexing to CoreIR index expressions
        # Contains FULL logic (no delegation to transformer)
        class IndexAccessRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(Aurora::AST::IndexAccess)
          end

          def apply(node, context = {})
            transformer = context.fetch(:transformer)

            # Transform array and index expressions recursively
            object = transformer.send(:transform_expression, node.object)
            index = transformer.send(:transform_expression, node.index)

            # Validate: object must be array type
            unless object.type.is_a?(Aurora::CoreIR::ArrayType)
              transformer.send(:type_error, "Indexing requires an array, got #{transformer.send(:describe_type, object.type)}", node: node.object)
            end

            # Validate: index must be numeric
            transformer.send(:ensure_numeric_type, index.type, "array index", node: node.index)

            # Build CoreIR index access with array element type
            Aurora::CoreIR::IndexExpr.new(
              object: object,
              index: index,
              type: object.type.element_type
            )
          end
        end
      end
    end
  end
end

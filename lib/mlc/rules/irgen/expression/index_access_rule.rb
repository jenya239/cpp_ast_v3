# frozen_string_literal: true

require_relative "../../base_rule"

module MLC
  module Rules
    module IRGen
      module Expression
        # IndexAccessRule: Transform AST array indexing to HighIR index expressions
        # Contains FULL logic (no delegation to transformer)
        class IndexAccessRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(MLC::AST::IndexAccess)
          end

          def apply(node, context = {})
            transformer = context.fetch(:transformer)
            expr_svc = context.fetch(:expression_transformer)
            type_checker = context.fetch(:type_checker)

            # Transform array and index expressions recursively
            object = expr_svc.transform_expression(node.object)
            index = expr_svc.transform_expression(node.index)

            # Validate: object must be array type
            unless object.type.is_a?(MLC::HighIR::ArrayType)
              type_checker.type_error("Indexing requires an array, got #{type_checker.describe_type(object.type)}", node: node.object)
            end

            # Validate: index must be numeric
            type_checker.ensure_numeric_type(index.type, "array index", node: node.index)

            # Build HighIR index access with array element type
            MLC::HighIR::IndexExpr.new(
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

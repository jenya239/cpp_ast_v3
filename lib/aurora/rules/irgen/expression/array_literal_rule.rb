# frozen_string_literal: true

require_relative "../../base_rule"

module Aurora
  module Rules
    module IRGen
      module Expression
        # ArrayLiteralRule: Transform AST array literals to CoreIR array expressions
        # Contains FULL logic (no delegation to transformer)
        class ArrayLiteralRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(Aurora::AST::ArrayLiteral)
          end

          def apply(node, context = {})
            transformer = context.fetch(:transformer)
            expr_svc = context.fetch(:expression_transformer)
            type_checker = context.fetch(:type_checker)

            # Transform each element recursively
            elements = node.elements.map { |elem| expr_svc.transform_expression(elem) }

            # Infer element type from first element (or default to i32)
            element_type = if elements.any?
                             elements.first.type
                           else
                             Aurora::CoreIR::Builder.primitive_type("i32")
                           end

            # Validate type compatibility for all elements
            elements.each_with_index do |elem, index|
              next if index.zero?
              type_checker.ensure_compatible(elem.type, element_type, "array element #{index}")
            end

            # Create array type and build array literal expression
            array_type = Aurora::CoreIR::ArrayType.new(element_type: element_type)

            Aurora::CoreIR::ArrayLiteralExpr.new(
              elements: elements,
              type: array_type
            )
          end
        end
      end
    end
  end
end

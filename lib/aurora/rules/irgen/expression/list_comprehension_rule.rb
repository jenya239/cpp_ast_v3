# frozen_string_literal: true

require_relative "../../base_rule"

module Aurora
  module Rules
    module IRGen
      module Expression
        # ListComprehensionRule: Transform AST list comprehensions to CoreIR
        # Contains FULL logic (no delegation to transformer)
        # Handles generators, filters, and output expression with scoping
        class ListComprehensionRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(Aurora::AST::ListComprehension)
          end

          def apply(node, context = {})
            transformer = context.fetch(:transformer)
            expr_svc = context.fetch(:expression_transformer)
            type_checker = context.fetch(:type_checker)

            # Save variable types for scoping
            saved_var_types = transformer.instance_variable_get(:@var_types).dup

            # Transform generators and add variables to scope
            generators = []

            node.generators.each do |gen|
              iterable_ir = expr_svc.transform_expression(gen.iterable)
              element_type = type_checker.infer_iterable_type(iterable_ir)

              generators << {
                var_name: gen.var_name,
                iterable: iterable_ir,
                var_type: element_type
              }

              # Add generator variable to scope
              transformer.instance_variable_get(:@var_types)[gen.var_name] = element_type
            end

            # Transform filters
            filters = node.filters.map { |filter| expr_svc.transform_expression(filter) }

            # Transform output expression with generators in scope
            output_expr = expr_svc.transform_expression(node.output_expr)
            element_type = output_expr.type || Aurora::CoreIR::Builder.primitive_type("i32")

            # Build array type and list comprehension expression
            array_type = Aurora::CoreIR::ArrayType.new(element_type: element_type)

            Aurora::CoreIR::ListCompExpr.new(
              element_type: element_type,
              generators: generators,
              filters: filters,
              output_expr: output_expr,
              type: array_type
            )
          ensure
            # Restore previous variable types scope
            transformer.instance_variable_set(:@var_types, saved_var_types) if saved_var_types
          end
        end
      end
    end
  end
end

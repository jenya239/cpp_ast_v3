# frozen_string_literal: true

require_relative "../../base_rule"

module MLC
  module Rules
    module IRGen
      module Statement
        # ForRule: Transform AST for-loop statements to HighIR
        # Contains FULL logic (no delegation to transformer)
        # Manages loop variable scoping and loop depth for break/continue
        class ForRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(MLC::AST::ForLoop)
          end

          def apply(node, context = {})
            transformer = context.fetch(:transformer)
            expr_svc = context.fetch(:expression_transformer)
            type_checker = context.fetch(:type_checker)
            context_mgr = context.fetch(:context_manager)

            # Transform iterable expression
            iterable_ir = expr_svc.transform_expression(node.iterable)

            # Save loop variable if it exists (for scope restoration)
            var_types = transformer.instance_variable_get(:@var_types)
            saved = var_types[node.var_name]

            # Infer element type from iterable
            element_type = type_checker.infer_iterable_type(iterable_ir)

            # Add loop variable to scope
            var_types[node.var_name] = element_type

            # Transform body within loop scope (for break/continue validation)
            body_ir = context_mgr.within_loop do
              expr_svc.transform_statement_block(node.body, preserve_scope: true)
            end

            # Build for statement
            [MLC::HighIR::Builder.for_stmt(node.var_name, element_type, iterable_ir, body_ir)]
          ensure
            # Restore previous loop variable binding
            if saved
              var_types[node.var_name] = saved
            else
              var_types.delete(node.var_name)
            end
          end
        end
      end
    end
  end
end

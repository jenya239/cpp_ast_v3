# frozen_string_literal: true

require_relative "../../base_rule"

module MLC
  module Rules
    module IRGen
      module Statement
        # BreakRule: Transform AST break statements to HighIR
        # Contains FULL logic (no delegation to transformer)
        class BreakRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(MLC::AST::Break)
          end

          def apply(node, context = {})
            transformer = context.fetch(:transformer)
            type_checker = context.fetch(:type_checker)

            # Validate: break must be inside loop
            loop_depth = transformer.instance_variable_get(:@loop_depth).to_i
            if loop_depth <= 0
              type_checker.type_error("'break' used outside of loop", node: node)
            end

            # Build break statement
            [MLC::HighIR::Builder.break_stmt]
          end
        end
      end
    end
  end
end

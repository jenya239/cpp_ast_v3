# frozen_string_literal: true

require_relative "../../base_rule"

module Aurora
  module Rules
    module IRGen
      module Statement
        # ContinueRule: Transform AST continue statements to CoreIR
        # Contains FULL logic (no delegation to transformer)
        class ContinueRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(Aurora::AST::Continue)
          end

          def apply(node, context = {})
            transformer = context.fetch(:transformer)
            type_checker = context.fetch(:type_checker)

            # Validate: continue must be inside loop
            loop_depth = transformer.instance_variable_get(:@loop_depth).to_i
            if loop_depth <= 0
              type_checker.type_error("'continue' used outside of loop", node: node)
            end

            # Build continue statement
            [Aurora::CoreIR::Builder.continue_stmt]
          end
        end
      end
    end
  end
end

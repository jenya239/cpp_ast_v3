# frozen_string_literal: true

require_relative "../../base_rule"

module Aurora
  module Rules
    module IRGen
      module Expression
        # LetRule: Transform AST let expressions to CoreIR by normalizing to block expressions
        # Contains FULL logic (no delegation to transformer)
        # Converts let binding + body into block with variable declaration
        class LetRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(Aurora::AST::Let)
          end

          def apply(node, context = {})
            transformer = context.fetch(:transformer)

            # Normalize let expression as block expression
            # This ensures type annotations, mutability checks, and scope management
            # flow through the same code paths as regular blocks

            # Create variable declaration from let binding
            variable_decl = Aurora::AST::VariableDecl.new(
              name: node.name,
              value: node.value,
              mutable: node.mutable,
              type: node.type,
              origin: node.origin
            )

            # Create block with declaration statement and body as result
            block = Aurora::AST::BlockExpr.new(
              statements: [variable_decl],
              result_expr: node.body,
              origin: node.origin
            )

            # Transform the normalized block
            transformer.send(:transform_block_expr, block)
          end
        end
      end
    end
  end
end

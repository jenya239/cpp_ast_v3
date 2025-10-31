# frozen_string_literal: true

require_relative "../../base_rule"
require_relative "../../../backend/codegen/helpers"

module MLC
  module Rules
    module CodeGen
      module Expression
        # Rule for lowering HighIR member access to C++ member access (.)
        # Contains logic, delegates recursion to lowerer for object expression
        class MemberRule < BaseRule
          include MLC::Backend::CodeGenHelpers

          def applies?(node, _context = {})
            node.is_a?(MLC::HighIR::MemberExpr)
          end

          def apply(node, context = {})
            lowerer = context[:lowerer]

            # Recursively lower the object being accessed
            object = lowerer.send(:lower_expression, node.object)

            CppAst::Nodes::MemberAccessExpression.new(
              object: object,
              operator: ".",
              member: CppAst::Nodes::Identifier.new(name: sanitize_identifier(node.member))
            )
          end
        end
      end
    end
  end
end

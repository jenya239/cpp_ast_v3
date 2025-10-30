# frozen_string_literal: true

require_relative "../../base_rule"
require_relative "../../../backend/cpp_lowering/helpers"

module Aurora
  module Rules
    module Cpp
      module Expression
        # Rule for lowering CoreIR member access to C++ member access (.)
        # Contains logic, delegates recursion to lowerer for object expression
        class MemberRule < BaseRule
          include Aurora::Backend::CppLoweringHelpers

          def applies?(node, _context = {})
            node.is_a?(Aurora::CoreIR::MemberExpr)
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

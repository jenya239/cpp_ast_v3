# frozen_string_literal: true

require_relative "../../base_rule"

module Aurora
  module Rules
    module CodeGen
      module Statement
        # Rule for lowering CoreIR continue statements to C++ continue statements
        class ContinueRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(Aurora::CoreIR::ContinueStmt)
          end

          def apply(node, context = {})
            CppAst::Nodes::ContinueStatement.new
          end
        end
      end
    end
  end
end

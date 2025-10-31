# frozen_string_literal: true

require_relative "../../base_rule"

module MLC
  module Rules
    module CodeGen
      module Statement
        # Rule for lowering HighIR continue statements to C++ continue statements
        class ContinueRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(MLC::HighIR::ContinueStmt)
          end

          def apply(node, context = {})
            CppAst::Nodes::ContinueStatement.new
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

require_relative "../../delegating_rule"

module Aurora
  module Rules
    module CoreIR
      module Statement
        class BlockRule < DelegatingRule
          handles Aurora::AST::Block, method: :transform_block_statement
        end
      end
    end
  end
end

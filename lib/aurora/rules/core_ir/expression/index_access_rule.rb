# frozen_string_literal: true

require_relative "../../delegating_rule"

module Aurora
  module Rules
    module CoreIR
      module Expression
        class IndexAccessRule < DelegatingRule
          handles Aurora::AST::IndexAccess, method: :transform_index_access
        end
      end
    end
  end
end

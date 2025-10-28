# frozen_string_literal: true

require_relative "../../delegating_rule"

module Aurora
  module Rules
    module CoreIR
      module Expression
        class VarRefRule < DelegatingRule
          handles Aurora::AST::VarRef, method: :transform_var_ref
        end
      end
    end
  end
end

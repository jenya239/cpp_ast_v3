# frozen_string_literal: true

require_relative "../../delegating_rule"

module Aurora
  module Rules
    module CoreIR
      module Expression
        class LetRule < DelegatingRule
          handles Aurora::AST::Let, method: :transform_let
        end
      end
    end
  end
end

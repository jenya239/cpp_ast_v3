# frozen_string_literal: true

require_relative "../../delegating_rule"

module Aurora
  module Rules
    module CoreIR
      module Expression
        class RecordLiteralRule < DelegatingRule
          handles Aurora::AST::RecordLit, method: :transform_record_literal
        end
      end
    end
  end
end

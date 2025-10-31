# frozen_string_literal: true

require_relative "../delegating_rule"

module Aurora
  module Rules
    module CodeGen
      # Base class for C++ expression lowering rules
      # Delegates to methods in CppLowering::ExpressionLowerer
      class CppExpressionRule < DelegatingRule
        class << self
          # Helper method for defining C++ expression rules
          # @param node_classes [Array<Class>] CoreIR expression classes to handle
          # @param method [Symbol] Method name in ExpressionLowerer to delegate to
          def handles_cpp_expr(node_classes, method:)
            handles(node_classes, method: method, via: :lowerer)
          end

          def context_key
            :lowerer
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

require_relative "../delegating_rule"

module MLC
  module Rules
    module CodeGen
      # Base class for C++ statement lowering rules
      # Delegates to statement lowering methods in CppLowering::StatementLowerer
      class CppStatementRule < DelegatingRule
        class << self
          # Define a rule that handles specific HighIR statement node classes
          # @param node_classes [Array<Class>] HighIR statement node classes to handle
          # @param method [Symbol] Name of the lowering method in StatementLowerer
          def handles_cpp_stmt(node_classes, method:)
            handles(node_classes, method: method, via: :lowerer)
          end

          # Context key for accessing the lowerer instance
          def context_key
            :lowerer
          end
        end
      end
    end
  end
end

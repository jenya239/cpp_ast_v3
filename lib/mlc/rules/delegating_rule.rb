# frozen_string_literal: true

require_relative "base_rule"

module MLC
  module Rules
    class DelegatingRule < BaseRule
      class << self
        attr_reader :handled_classes, :delegate_method, :delegate_context_key

        def handles(node_classes, method:, via: :transformer)
          @handled_classes = Array(node_classes)
          @delegate_method = method
          @delegate_context_key = via
        end

        def context_key
          @delegate_context_key || :transformer
        end
      end

      def applies?(node, _context = {})
        handled_classes = self.class.handled_classes
        handled_classes && handled_classes.any? { |klass| node.is_a?(klass) }
      end

      def apply(node, context = {})
        delegate = context.fetch(self.class.context_key)
        delegate.public_send(self.class.delegate_method, node)
      end
    end
  end
end

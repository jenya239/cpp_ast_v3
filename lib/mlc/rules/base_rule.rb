# frozen_string_literal: true

module MLC
  module Rules
    class BaseRule
      # Override in subclasses to indicate whether the rule should run
      def applies?(_node, _context = {})
        false
      end

      # Override in subclasses to implement the rule's behaviour
      def apply(_node, _context = {})
        # no-op by default
      end
    end
  end
end

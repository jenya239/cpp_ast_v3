# frozen_string_literal: true

module CppAst
  module Nodes
    # Base class for ownership type wrappers
    class OwnershipType < Node
      attr_accessor :inner_type

      def initialize(inner_type:)
        @inner_type = inner_type
      end

      def to_source
        raise NotImplementedError, "Subclasses must implement to_source"
      end
    end

    # std::unique_ptr<T>
    class OwnedType < OwnershipType
      def to_source
        "std::unique_ptr<#{inner_type}>"
      end
    end

    # const T&
    class BorrowedType < OwnershipType
      def to_source
        "const #{inner_type}&"
      end
    end

    # T&
    class MutBorrowedType < OwnershipType
      def to_source
        "#{inner_type}&"
      end
    end

    # std::span<T>
    class SpanType < OwnershipType
      def to_source
        "std::span<#{inner_type}>"
      end
    end
  end
end

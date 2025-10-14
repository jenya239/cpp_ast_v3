# frozen_string_literal: true

module CppAst
  module Nodes
    # Base class for Result/Option type wrappers
    class ResultType < Node
      attr_accessor :ok_type, :err_type

      def initialize(ok_type:, err_type:)
        @ok_type = ok_type
        @err_type = err_type
      end

      def to_source
        raise NotImplementedError, "Subclasses must implement to_source"
      end
    end

    # std::expected<T, E>
    class ExpectedType < ResultType
      def to_source
        "std::expected<#{ok_type}, #{err_type}>"
      end
    end

    # std::optional<T>
    class OptionalType < Node
      attr_accessor :inner_type

      def initialize(inner_type:)
        @inner_type = inner_type
      end

      def to_source
        "std::optional<#{inner_type}>"
      end
    end

    # Ok(value) constructor
    class OkValue < Expression
      attr_accessor :value

      def initialize(value:)
        @value = value
      end

      def to_source
        value_str = value.respond_to?(:to_source) ? value.to_source : value.to_s
        "Ok(#{value_str})"
      end
    end

    # Err(error) constructor
    class ErrValue < Expression
      attr_accessor :error

      def initialize(error:)
        @error = error
      end

      def to_source
        error_str = error.respond_to?(:to_source) ? error.to_source : error.to_s
        "Err(#{error_str})"
      end
    end

    # Some(value) constructor
    class SomeValue < Expression
      attr_accessor :value

      def initialize(value:)
        @value = value
      end

      def to_source
        value_str = value.respond_to?(:to_source) ? value.to_source : value.to_s
        "Some(#{value_str})"
      end
    end

    # None constructor
    class NoneValue < Expression
      def to_source
        "None"
      end
    end
  end
end

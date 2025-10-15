# frozen_string_literal: true

module CppAst
  module Nodes
    class Parameter < Statement
      attr_accessor :type, :name, :default_value
      attr_accessor :type_suffix, :equals_prefix, :equals_suffix
      
      def initialize(type:, name:, default_value: nil,
                     type_suffix: " ", equals_prefix: " ", equals_suffix: " ")
        @type = type
        @name = name
        @default_value = default_value
        @type_suffix = type_suffix
        @equals_prefix = equals_prefix
        @equals_suffix = equals_suffix
      end
      
      def to_source
        type_str = type.respond_to?(:to_source) ? type.to_source : type.to_s
        result = "#{type_str}#{type_suffix}#{name}"
        if default_value
          result << "#{equals_prefix}=#{equals_suffix}#{default_value}"
        end
        result
      end
    end
  end
end

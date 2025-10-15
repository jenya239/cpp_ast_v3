# frozen_string_literal: true

module CppAst
  module Builder
    module Defaults
      COMPACT = {
        enum_name_suffix: "",
        class_name_suffix: "",
        template_suffix: "",
        friend_suffix: "",
        type_suffix: ""
      }.freeze
      
      PRETTY = {
        enum_name_suffix: " ",
        class_name_suffix: " ",
        template_suffix: " ",
        friend_suffix: " ",
        type_suffix: " "
      }.freeze
      
      @mode = :compact
      
      def self.mode=(m)
        @mode = m
      end
      
      def self.get(key)
        (@mode == :compact ? COMPACT : PRETTY)[key] || ""
      end
      
      def self.compact!
        @mode = :compact
      end
      
      def self.pretty!
        @mode = :pretty
      end
    end
  end
end
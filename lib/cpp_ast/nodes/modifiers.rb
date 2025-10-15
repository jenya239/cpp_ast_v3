# frozen_string_literal: true

module CppAst
  module Nodes
    class ModifierSet
      PRIORITY = {
        constexpr: 1,
        static: 2,
        explicit: 3,
        inline: 4,
        virtual: 5,
        maybe_unused: 9,  # атрибуты перед nodiscard
        nodiscard: 10     # атрибуты в конце префиксов
      }.freeze
      
      def initialize
        @modifiers = {}
      end
      
      def add(name)
        @modifiers[name.to_sym] = true
        self
      end
      
      def to_s
        sorted = @modifiers.keys.sort_by { |k| PRIORITY[k] || 99 }
        sorted.map { |k| format_modifier(k) }.join
      end
      
      private
      
      def format_modifier(name)
        case name
        when :nodiscard then "[[nodiscard]] "
        when :maybe_unused then "[[maybe_unused]] "
        when :explicit then "explicit "
        else "#{name} "
        end
      end
    end
  end
end

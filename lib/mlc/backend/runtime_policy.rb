# frozen_string_literal: true

module MLC
  module Backend
    # RuntimePolicy - конфигурация стратегий lowering
    # Определяет когда использовать IIFE, runtime helpers, или inline генерацию
    class RuntimePolicy
      # Стратегии для block expressions
      BLOCK_STRATEGIES = %i[iife scope_tmp gcc_expr inline].freeze

      # Стратегии для if expressions
      IF_STRATEGIES = %i[ternary variant_tmp inline_if].freeze

      # Стратегии для match expressions
      MATCH_STRATEGIES = %i[std_visit iife named_visitor].freeze

      attr_accessor :block_expr_simple_strategy    # Для простых блоков (≤3 stmts, no ctrl flow)
      attr_accessor :block_expr_complex_strategy   # Для сложных блоков
      attr_accessor :if_join_strategy              # Для if expressions
      attr_accessor :match_threshold               # Порог для named visitor (кол-во веток)
      attr_accessor :loop_capture_strategy         # :lambda или :fn_ptr
      attr_accessor :use_gcc_extensions            # Использовать ли ({ }) expressions
      attr_accessor :error_model                   # :expected или :exceptions
      attr_accessor :always_use_runtime            # Всегда использовать runtime для collections

      def initialize
        # По умолчанию: консервативная стратегия (используем IIFE везде)
        @block_expr_simple_strategy = :iife      # Можно переключить на :scope_tmp или :gcc_expr
        @block_expr_complex_strategy = :iife
        @if_join_strategy = :ternary
        @match_threshold = 5                     # >5 веток → named visitor (в будущем)
        @loop_capture_strategy = :lambda
        @use_gcc_extensions = false              # ({ }) работает только в GCC
        @error_model = :expected                 # Когда добавим Expected<T,E>
        @always_use_runtime = true               # map/filter/fold всегда через runtime
      end

      # Выбрать стратегию для block expression
      def strategy_for_block(block_analysis)
        # Trivial blocks (только result, без statements) - inline
        return :inline if block_analysis.trivial?

        if block_analysis.simple?
          @block_expr_simple_strategy
        else
          @block_expr_complex_strategy
        end
      end

      # Выбрать стратегию для if expression
      def strategy_for_if(if_analysis)
        if if_analysis.simple_ternary_candidate?
          :ternary
        elsif if_analysis.same_types?
          :inline_if
        else
          :variant_tmp
        end
      end

      # Выбрать стратегию для match expression
      def strategy_for_match(match_analysis)
        if match_analysis.has_regex?
          :iife
        elsif match_analysis.arm_count > @match_threshold
          :named_visitor  # Пока не реализовано, fallback на iife
        else
          :std_visit
        end
      end

      # Клонировать с изменениями
      def with(**overrides)
        copy = self.dup
        overrides.each { |key, value| copy.send("#{key}=", value) }
        copy
      end

      # Предопределенные политики

      # Оптимизированная политика (минимум IIFE)
      def self.optimized
        new.tap do |p|
          p.block_expr_simple_strategy = :scope_tmp
          p.use_gcc_extensions = false
        end
      end

      # GCC-оптимизированная политика
      def self.gcc_optimized
        new.tap do |p|
          p.block_expr_simple_strategy = :gcc_expr
          p.use_gcc_extensions = true
        end
      end

      # Консервативная политика (совместимость)
      def self.conservative
        new  # Defaults to IIFE everywhere
      end
    end
  end
end

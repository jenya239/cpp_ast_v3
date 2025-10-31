# frozen_string_literal: true

module MLC
  module Backend
    # BlockComplexityAnalyzer - анализ сложности block expressions
    # Определяет можно ли использовать простую стратегию или нужен IIFE
    class BlockComplexityAnalyzer
      attr_reader :block_expr, :statement_count, :has_control_flow, :has_early_return

      # Пороги для определения "простого" блока
      SIMPLE_STATEMENT_THRESHOLD = 3

      def initialize(block_expr)
        @block_expr = block_expr
        @statement_count = block_expr.statements.size
        @has_control_flow = analyze_control_flow
        @has_early_return = false  # В Aurora нет early return в блоках (пока)
      end

      # Простой блок: ≤3 statements, без control flow
      def simple?
        @statement_count <= SIMPLE_STATEMENT_THRESHOLD &&
          !@has_control_flow &&
          all_statements_simple?
      end

      # Сложный блок нуждается в IIFE
      def complex?
        !simple?
      end

      # Блок с единственным expression (можно inline)
      def trivial?
        @statement_count == 0
      end

      # Есть ли вложенные if/match/loop
      def has_nested_constructs?
        @has_control_flow
      end

      # Оценка стоимости генерации (для метрик)
      def complexity_score
        score = @statement_count
        score += 5 if @has_control_flow
        score += 3 if @has_early_return
        score += 2 if has_nested_blocks?
        score
      end

      private

      def analyze_control_flow
        # Проверяем есть ли if/match/loop в statements или result
        statements_have_control_flow = @block_expr.statements.any? do |stmt|
          statement_has_control_flow?(stmt)
        end

        result_has_control_flow = if @block_expr.result
          expression_has_control_flow?(@block_expr.result)
        else
          false
        end

        statements_have_control_flow || result_has_control_flow
      end

      def statement_has_control_flow?(stmt)
        case stmt
        when HighIR::IfStmt, HighIR::MatchStmt, HighIR::ForStmt, HighIR::WhileStmt
          true
        when HighIR::VariableDeclStmt
          stmt.value && expression_has_control_flow?(stmt.value)
        when HighIR::ExprStmt
          expression_has_control_flow?(stmt.expr)
        else
          false
        end
      end

      def expression_has_control_flow?(expr)
        case expr
        when HighIR::IfExpr, HighIR::MatchExpr
          true
        when HighIR::BlockExpr
          true  # Вложенный блок считаем как control flow
        when HighIR::CallExpr
          # Рекурсивно проверяем аргументы
          expr.args.any? { |arg| expression_has_control_flow?(arg) }
        when HighIR::BinaryExpr
          expression_has_control_flow?(expr.left) || expression_has_control_flow?(expr.right)
        else
          false
        end
      end

      def all_statements_simple?
        @block_expr.statements.all? do |stmt|
          simple_statement?(stmt)
        end
      end

      def simple_statement?(stmt)
        case stmt
        when HighIR::VariableDeclStmt
          # let без сложных инициализаторов
          !stmt.value || !expression_has_control_flow?(stmt.value)
        when HighIR::ExprStmt
          # Простой expression statement (call, assignment)
          !expression_has_control_flow?(stmt.expr)
        when HighIR::AssignmentStmt
          true  # Assignments всегда простые
        else
          false
        end
      end

      def has_nested_blocks?
        @block_expr.statements.any? do |stmt|
          stmt.is_a?(HighIR::VariableDeclStmt) && stmt.value.is_a?(HighIR::BlockExpr)
        end
      end
    end

    # Анализ if expressions
    class IfComplexityAnalyzer
      attr_reader :if_expr

      def initialize(if_expr)
        @if_expr = if_expr
      end

      # Можно ли использовать ternary (? :)
      def simple_ternary_candidate?
        simple_branch?(@if_expr.then_branch) &&
          simple_branch?(@if_expr.else_branch) &&
          !has_nested_control_flow?
      end

      # Типы веток одинаковые (не нужен variant)
      def same_types?
        return false unless @if_expr.then_branch && @if_expr.else_branch

        # Проверка через type system (если доступен)
        then_type = @if_expr.then_branch.type rescue nil
        else_type = @if_expr.else_branch.type rescue nil

        return true unless then_type && else_type
        then_type == else_type
      end

      private

      def simple_branch?(branch)
        return false unless branch

        case branch
        when HighIR::LiteralExpr, HighIR::VarExpr
          true
        when HighIR::BinaryExpr
          # Простая арифметика
          simple_branch?(branch.left) && simple_branch?(branch.right)
        when HighIR::CallExpr
          # Простой вызов функции
          branch.args.all? { |arg| simple_branch?(arg) }
        else
          false
        end
      end

      def has_nested_control_flow?
        [*@if_expr.then_branch, @if_expr.else_branch].compact.any? do |branch|
          branch.is_a?(HighIR::IfExpr) ||
            branch.is_a?(HighIR::MatchExpr) ||
            branch.is_a?(HighIR::BlockExpr)
        end
      end
    end

    # Анализ match expressions
    class MatchComplexityAnalyzer
      attr_reader :match_expr

      def initialize(match_expr)
        @match_expr = match_expr
      end

      def arm_count
        @match_expr.arms.size
      end

      def has_regex?
        @match_expr.arms.any? do |arm|
          arm[:pattern][:kind] == :regex
        end
      end

      def pure_adt_match?
        !has_regex? && all_constructor_patterns?
      end

      def needs_named_visitor?(threshold = 5)
        arm_count > threshold && pure_adt_match?
      end

      private

      def all_constructor_patterns?
        @match_expr.arms.all? do |arm|
          [:constructor, :wildcard, :var].include?(arm[:pattern][:kind])
        end
      end
    end
  end
end

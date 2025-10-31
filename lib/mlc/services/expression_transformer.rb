# frozen_string_literal: true

module MLC
  module Services
    # ExpressionTransformer - сервис для рекурсивной трансформации expressions и statements
    # Заменяет вызовы transformer.send(:transform_expression, ...) из правил
    #
    # Использование:
    #   transformer = context[:expression_transformer]
    #   result = transformer.transform_expression(ast_node)
    class ExpressionTransformer
      def initialize(base_transformer)
        @transformer = base_transformer
      end

      # Трансформация expression из AST в HighIR
      def transform_expression(node)
        @transformer.send(:transform_expression, node)
      end

      # Трансформация statement block
      def transform_statement_block(node, preserve_scope: false)
        @transformer.send(:transform_statement_block, node, preserve_scope: preserve_scope)
      end

      # Трансформация block expression
      def transform_block_expr(node)
        @transformer.send(:transform_block_expr, node)
      end

      # Трансформация type
      def transform_type(node)
        @transformer.send(:transform_type, node)
      end

      # Трансформация for statement
      def transform_for_statement(node)
        @transformer.send(:transform_for_statement, node)
      end

      # Трансформация while statement
      def transform_while_statement(condition_node, body_node)
        @transformer.send(:transform_while_statement, condition_node, body_node)
      end

      # Трансформация block
      def transform_block(node, require_value: true)
        @transformer.send(:transform_block, node, require_value: require_value)
      end

      # Трансформация if statement
      def transform_if_statement(condition, then_branch, else_branch)
        @transformer.send(:transform_if_statement, condition, then_branch, else_branch)
      end
    end
  end
end

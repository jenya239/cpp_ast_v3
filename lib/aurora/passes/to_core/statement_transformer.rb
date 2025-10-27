# frozen_string_literal: true

module Aurora
  module Passes
    class ToCore
      # StatementTransformer
      # Statement transformation and control flow
      # Auto-extracted from to_core.rb during refactoring
      module StatementTransformer
      def transform_block(block, require_value: true, preserve_scope: false)
        with_current_node(block) do
          saved_var_types = @var_types.dup unless preserve_scope
          if block.stmts.empty?
            if require_value
              type_error("Block must end with an expression")
            else
              return CoreIR::Builder.block_expr(
                [],
                nil,
                CoreIR::Builder.primitive_type("void")
              )
            end
          end

          statements = block.stmts.dup
          tail = require_value ? statements.pop : nil

          statement_nodes = transform_statements(statements)
          result_ir = nil

          if require_value && tail
            case tail
            when AST::ExprStmt
              result_ir = transform_expression(tail.expr)
            when AST::Return
              statement_nodes << transform_return_statement(tail)
            else
              statement_nodes.concat(transform_statements([tail]))
            end
          end

          block_type = result_ir ? result_ir.type : CoreIR::Builder.primitive_type("void")
          CoreIR::Builder.block_expr(statement_nodes, result_ir, block_type)
        ensure
          @var_types = saved_var_types if defined?(saved_var_types) && !preserve_scope
        end
      end

      def transform_expr_statement(expr_stmt)
        expr = expr_stmt.expr
        case expr
        when AST::ForLoop
          [transform_for_statement(expr)]
        when AST::IfExpr
          [transform_if_statement(expr.condition, expr.then_branch, expr.else_branch)]
        when AST::WhileLoop
          [transform_while_statement(expr.condition, expr.body)]
        when AST::Block
          transform_block(expr, require_value: false).statements
        else
          ir = transform_expression(expr)
          if expr.is_a?(AST::IfExpr) && ir.is_a?(CoreIR::IfExpr)
            CoreIR::Builder.if_stmt(ir.condition, transform_statement_block(expr.then_branch), expr.else_branch ? transform_statement_block(expr.else_branch) : nil)
            []
          else
            [CoreIR::Builder.expr_statement(ir)]
          end
        end
      end

      def transform_for_statement(stmt)
        iterable_ir = transform_expression(stmt.iterable)
        saved = @var_types[stmt.var_name]
        element_type = infer_iterable_type(iterable_ir)
        @var_types[stmt.var_name] = element_type
        body_ir = within_loop_scope { transform_statement_block(stmt.body, preserve_scope: true) }

        CoreIR::Builder.for_stmt(stmt.var_name, element_type, iterable_ir, body_ir)
      ensure
        if saved
          @var_types[stmt.var_name] = saved
        else
          @var_types.delete(stmt.var_name)
        end
      end

      def transform_if_statement(condition_node, then_node, else_node)
        condition_ir = transform_expression(condition_node)
        ensure_boolean_type(condition_ir.type, "if condition", node: condition_node)
        then_ir = transform_statement_block(then_node)
        else_ir = else_node ? transform_statement_block(else_node) : nil
        CoreIR::Builder.if_stmt(condition_ir, then_ir, else_ir)
      end

      def transform_return_statement(stmt)
        expected = current_function_return
        type_error("return statement outside of function") unless expected

        expr_ir = stmt.expr ? transform_expression(stmt.expr) : nil

        if void_type?(expected)
          type_error("return value not allowed in void function", node: stmt) if expr_ir
        else
          unless expr_ir
            expected_name = describe_type(expected)
            type_error("return statement requires a value of type #{expected_name}", node: stmt)
          end
          ensure_compatible_type(expr_ir.type, expected, "return statement", node: stmt)
        end

        CoreIR::Builder.return_stmt(expr_ir)
      end

      def transform_statement_block(node, preserve_scope: false)
        block_ast =
          case node
          when AST::Block
            node
          when AST::Stmt
            AST::Block.new(stmts: [node])
          else
            AST::Block.new(stmts: [AST::ExprStmt.new(expr: node)])
          end

        transform_block(block_ast, require_value: false, preserve_scope: preserve_scope)
      end

      def transform_statements(statements)
        statements.each_with_object([]) do |stmt, acc|
          with_current_node(stmt) do
            case stmt
            when AST::ExprStmt
              acc.concat(transform_expr_statement(stmt))
            when AST::VariableDecl
              value_ir = transform_expression(stmt.value)

              # Use explicit type annotation if provided, otherwise infer from value
              var_type = if stmt.type
                           explicit_type = transform_type(stmt.type)

                           # If value is an anonymous record and explicit type is provided,
                           # update the record's type to match the explicit type
                           if value_ir.is_a?(CoreIR::RecordExpr) && value_ir.type_name == "record"
                             # Extract the actual type name from explicit_type
                             actual_type_name = type_name(explicit_type)
                             # Replace the anonymous record type with the explicit type
                             value_ir = CoreIR::Builder.record(actual_type_name, value_ir.fields, explicit_type)
                           else
                             # Verify that value type is compatible with explicit type
                             ensure_compatible_type(value_ir.type, explicit_type, "variable '#{stmt.name}' initialization")
                           end

                           explicit_type
                         else
                           value_ir.type
                         end

              previous_type = @var_types[stmt.name]
              @var_types[stmt.name] = var_type
              acc << CoreIR::Builder.variable_decl_stmt(
                stmt.name,
                var_type,
                value_ir,
                mutable: stmt.mutable
              )
            when AST::Assignment
              unless stmt.target.is_a?(AST::VarRef)
                type_error("Assignment target must be a variable", node: stmt)
              end
              target_name = stmt.target.name
              existing_type = @var_types[target_name]
              type_error("Assignment to undefined variable '#{target_name}'", node: stmt) unless existing_type

              value_ir = transform_expression(stmt.value)
              ensure_compatible_type(value_ir.type, existing_type, "assignment to '#{target_name}'")
              @var_types[target_name] = existing_type
              target_ir = CoreIR::Builder.var(target_name, existing_type)
              acc << CoreIR::Builder.assignment_stmt(target_ir, value_ir)
            when AST::ForLoop
              acc << transform_for_statement(stmt)
            when AST::IfStmt
              acc << transform_if_statement(stmt.condition, stmt.then_branch, stmt.else_branch)
            when AST::WhileStmt
              acc << transform_while_statement(stmt.condition, stmt.body)
            when AST::Return
              acc << transform_return_statement(stmt)
            when AST::Break
              type_error("'break' used outside of loop", node: stmt) if @loop_depth.to_i <= 0
              acc << CoreIR::Builder.break_stmt
            when AST::Continue
              type_error("'continue' used outside of loop", node: stmt) if @loop_depth.to_i <= 0
              acc << CoreIR::Builder.continue_stmt
            when AST::Block
              nested = transform_block(stmt, require_value: false)
              acc.concat(nested.statements)
            else
              type_error("Unsupported statement: #{stmt.class}", node: stmt)
            end
          end
        end
      end

      def transform_while_statement(condition_node, body_node)
        condition_ir = transform_expression(condition_node)
        ensure_boolean_type(condition_ir.type, "while condition", node: condition_node)
        body_ir = within_loop_scope { transform_statement_block(body_node, preserve_scope: true) }
        CoreIR::Builder.while_stmt(condition_ir, body_ir)
      end

      def within_loop_scope
        @loop_depth ||= 0
        @loop_depth += 1
        yield
      ensure
        @loop_depth -= 1
      end

      end
    end
  end
end

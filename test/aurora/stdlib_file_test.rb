# frozen_string_literal: true

require_relative "../test_helper"

class StdlibFileTest < Minitest::Test
  def test_file_module_parses
    source = <<~AURORA
      import { read_to_string, write_string, exists } from "File"

      fn test() -> bool =
        exists("test.txt")
    AURORA

    ast = Aurora.parse(source)
    assert_equal 1, ast.imports.length
    assert_equal "File", ast.imports.first.path
  end

  def test_file_read_functions
    source = <<~AURORA
      import { read_to_string, read_lines, read_text } from "File"

      fn test_read_string() -> str =
        read_to_string("test.txt")

      fn test_read_lines() -> str[] =
        read_lines("test.txt")

      fn test_read_text() -> str =
        read_text("test.txt")
    AURORA

    cpp = Aurora.to_cpp(source)
    assert_includes cpp, "read_to_string"
    assert_includes cpp, "read_lines"
  end

  def test_file_write_functions
    source = <<~AURORA
      import { write_string, write_lines, write_text } from "File"

      fn test_write_string() -> bool =
        write_string("output.txt", "Hello")

      fn test_write_lines() -> bool =
        write_lines("output.txt", ["line1", "line2"])

      fn test_write_text() -> bool =
        write_text("output.txt", "content")
    AURORA

    cpp = Aurora.to_cpp(source)
    assert_includes cpp, "write_string"
    assert_includes cpp, "write_lines"
  end

  def test_file_append_functions
    source = <<~AURORA
      import { append_string, append_line, append_text } from "File"

      fn test_append_string() -> bool =
        append_string("log.txt", "message")

      fn test_append_line() -> bool =
        append_line("log.txt", "new line")

      fn test_append_text() -> bool =
        append_text("log.txt", "more text")
    AURORA

    cpp = Aurora.to_cpp(source)
    assert_includes cpp, "append_string"
    assert_includes cpp, "append_line"
  end

  def test_file_system_operations
    source = <<~AURORA
      import { exists, file_exists, remove_file, delete_file } from "File"

      fn test_exists() -> bool =
        exists("file.txt")

      fn test_file_exists() -> bool =
        file_exists("file.txt")

      fn test_remove() -> bool =
        remove_file("temp.txt")

      fn test_delete() -> bool =
        delete_file("temp.txt")
    AURORA

    cpp = Aurora.to_cpp(source)
    assert_includes cpp, "exists"
    assert_includes cpp, "remove_file"
  end

  def test_file_rename_move
    source = <<~AURORA
      import { rename_file, move_file } from "File"

      fn test_rename() -> bool =
        rename_file("old.txt", "new.txt")

      fn test_move() -> bool =
        move_file("src.txt", "dest.txt")
    AURORA

    cpp = Aurora.to_cpp(source)
    assert_includes cpp, "rename_file"
  end

  def test_file_combined_operations
    source = <<~AURORA
      import { read_to_string, write_string, exists } from "File"

      fn backup_file(path: str) -> bool =
        if exists(path)
          then write_string(path + ".bak", read_to_string(path))
          else false
    AURORA

    cpp = Aurora.to_cpp(source)
    assert_includes cpp, "backup_file"
    assert_includes cpp, "read_to_string"
    assert_includes cpp, "write_string"
    assert_includes cpp, "exists"
  end

  def test_safe_read_operations
    source = <<~AURORA
      import { safe_read_to_string, safe_read_lines } from "File"

      fn test_safe_read() -> Result<str, str> =
        safe_read_to_string("config.txt")

      fn test_safe_read_lines() -> Result<str[], str> =
        safe_read_lines("data.txt")
    AURORA

    cpp = Aurora.to_cpp(source)
    assert_includes cpp, "safe_read_to_string"
    assert_includes cpp, "safe_read_lines"
  end

  def test_safe_write_operations
    source = <<~AURORA
      import { safe_write_string, safe_write_lines, safe_append_string } from "File"

      fn test_safe_write() -> Result<bool, str> =
        safe_write_string("output.txt", "content")

      fn test_safe_write_lines() -> Result<bool, str> =
        safe_write_lines("output.txt", ["line1", "line2"])

      fn test_safe_append() -> Result<bool, str> =
        safe_append_string("log.txt", "entry")
    AURORA

    cpp = Aurora.to_cpp(source)
    assert_includes cpp, "safe_write_string"
    assert_includes cpp, "safe_write_lines"
    assert_includes cpp, "safe_append_string"
  end

  def test_safe_file_system_operations
    source = <<~AURORA
      import { safe_remove_file, safe_rename_file } from "File"

      fn test_safe_remove() -> Result<bool, str> =
        safe_remove_file("temp.txt")

      fn test_safe_rename() -> Result<bool, str> =
        safe_rename_file("old.txt", "new.txt")
    AURORA

    cpp = Aurora.to_cpp(source)
    assert_includes cpp, "safe_remove_file"
    assert_includes cpp, "safe_rename_file"
  end

  def test_safe_operations_with_result_combinators
    source = <<~AURORA
      import { safe_read_to_string, safe_write_string } from "File"
      import { is_ok, unwrap_or } from "Result"

      fn process_file(input_path: str, output_path: str) -> bool = do
        let result = safe_read_to_string(input_path)
        if is_ok(result)
          then is_ok(safe_write_string(output_path, unwrap_or(result, "")))
          else false
      end
    AURORA

    cpp = Aurora.to_cpp(source)
    assert_includes cpp, "process_file"
    assert_includes cpp, "safe_read_to_string"
    assert_includes cpp, "safe_write_string"
  end
end

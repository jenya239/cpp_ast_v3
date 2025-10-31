# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../lib/mlc"
require "tmpdir"
require "fileutils"

class AuroraMultiFileModulesTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("mlc_test")
  end

  def teardown
    FileUtils.rm_rf(@tmpdir) if @tmpdir && File.exist?(@tmpdir)
  end

  def test_compile_two_files_with_import
    # Create math.mlcora
    math_file = File.join(@tmpdir, "math.mlcora")
    File.write(math_file, <<~AURORA)
      export fn add(a: i32, b: i32) -> i32 = a + b
      export fn multiply(a: i32, b: i32) -> i32 = a * b
    AURORA

    # Create main.mlcora that imports from math
    main_file = File.join(@tmpdir, "main.mlcora")
    File.write(main_file, <<~AURORA)
      import { add, multiply } from "./math"

      export fn calculate(x: i32) -> i32 = add(x, 10)
    AURORA

    # Compile both files
    math_result = compile_aurora_file(math_file)
    main_result = compile_aurora_file(main_file)

    # Verify math.hpp was generated
    assert_includes math_result[:header], "int add(int a, int b);"
    assert_includes math_result[:header], "int multiply(int a, int b);"

    # Verify main.hpp imports math
    assert_includes main_result[:header], '#include "./math.hpp"'
    assert_includes main_result[:header], "int calculate(int x);"
  end

  def test_compile_nested_directories
    # Create directory structure:
    # tmpdir/
    #   main.mlcora
    #   math/
    #     vector.mlcora

    math_dir = File.join(@tmpdir, "math")
    FileUtils.mkdir_p(math_dir)

    # Create math/vector.mlcora
    vector_file = File.join(math_dir, "vector.mlcora")
    File.write(vector_file, <<~AURORA)
      export type Vec2 = { x: f32, y: f32 }

      export fn dot(a: Vec2, b: Vec2) -> f32 =
        a.x * b.x + a.y * b.y
    AURORA

    # Create main.mlcora that imports from subdirectory
    main_file = File.join(@tmpdir, "main.mlcora")
    File.write(main_file, <<~AURORA)
      import { Vec2, dot } from "./math/vector"

      export fn test() -> f32 =
        dot({ x: 1.0, y: 2.0 }, { x: 3.0, y: 4.0 })
    AURORA

    # Compile both
    vector_result = compile_aurora_file(vector_file)
    main_result = compile_aurora_file(main_file)

    # Verify struct was generated
    assert_includes vector_result[:header], "struct Vec2"
    assert_includes vector_result[:header], "float dot"

    # Verify import path
    assert_includes main_result[:header], '#include "./math/vector.hpp"'
  end

  def test_compile_parent_directory_import
    # Create directory structure:
    # tmpdir/
    #   core/
    #     utils.mlcora
    #   app/
    #     main.mlcora

    core_dir = File.join(@tmpdir, "core")
    app_dir = File.join(@tmpdir, "app")
    FileUtils.mkdir_p(core_dir)
    FileUtils.mkdir_p(app_dir)

    # Create core/utils.mlcora
    utils_file = File.join(core_dir, "utils.mlcora")
    File.write(utils_file, <<~AURORA)
      export fn helper() -> i32 = 42
    AURORA

    # Create app/main.mlcora that imports from parent
    main_file = File.join(app_dir, "main.mlcora")
    File.write(main_file, <<~AURORA)
      import { helper } from "../core/utils"

      export fn run() -> i32 = helper()
    AURORA

    # Compile both
    compile_aurora_file(utils_file)
    main_result = compile_aurora_file(main_file)

    # Verify parent path import
    assert_includes main_result[:header], '#include "../core/utils.hpp"'
    assert_includes main_result[:header], "int run();"
  end

  def test_compile_with_sum_types_across_files
    # Create types.mlcora with sum type
    types_file = File.join(@tmpdir, "types.mlcora")
    File.write(types_file, <<~AURORA)
      export type Result<T, E> = Ok(T) | Err(E)
    AURORA

    # Create main.mlcora that uses the sum type
    main_file = File.join(@tmpdir, "main.mlcora")
    File.write(main_file, <<~AURORA)
      import { Result } from "./types"

      export fn divide(a: i32, b: i32) -> Result<i32, i32> =
        match b
          | 0 => Err(1)
          | _ => Ok(a)
    AURORA

    # Compile both
    types_result = compile_aurora_file(types_file)
    main_result = compile_aurora_file(main_file)

    # Verify sum type was generated
    assert_includes types_result[:header], "struct Ok"
    assert_includes types_result[:header], "struct Err"

    # Verify import
    assert_includes main_result[:header], '#include "./types.hpp"'
  end

  def test_multiple_imports_from_same_file
    # Create utils.mlcora with multiple exports
    utils_file = File.join(@tmpdir, "utils.mlcora")
    File.write(utils_file, <<~AURORA)
      export fn add(a: i32, b: i32) -> i32 = a + b
      export fn sub(a: i32, b: i32) -> i32 = a - b
      export fn mul(a: i32, b: i32) -> i32 = a * b
    AURORA

    # Create main.mlcora importing multiple items
    main_file = File.join(@tmpdir, "main.mlcora")
    File.write(main_file, <<~AURORA)
      import { add, sub, mul } from "./utils"

      export fn calc(x: i32, y: i32) -> i32 =
        add(mul(x, y), sub(x, y))
    AURORA

    # Compile
    utils_result = compile_aurora_file(utils_file)
    main_result = compile_aurora_file(main_file)

    # Verify all exports
    assert_includes utils_result[:header], "int add"
    assert_includes utils_result[:header], "int sub"
    assert_includes utils_result[:header], "int mul"

    # Verify single import
    assert_equal 1, main_result[:header].scan(/#include "\.\/utils\.hpp"/).size
  end

  def test_wildcard_import
    # Create math.mlcora
    math_file = File.join(@tmpdir, "math.mlcora")
    File.write(math_file, <<~AURORA)
      export fn add(a: i32, b: i32) -> i32 = a + b
      export fn multiply(a: i32, b: i32) -> i32 = a * b
    AURORA

    # Create main.mlcora with wildcard import
    main_file = File.join(@tmpdir, "main.mlcora")
    File.write(main_file, <<~AURORA)
      import * as Math from "./math"

      export fn test() -> i32 = add(1, 2)
    AURORA

    # Compile
    main_result = compile_aurora_file(main_file)

    # Verify import
    assert_includes main_result[:header], '#include "./math.hpp"'
  end

  def test_write_generated_files_to_disk
    # Create a simple Aurora file
    aurora_file = File.join(@tmpdir, "test.mlcora")
    File.write(aurora_file, <<~AURORA)
      export fn hello() -> i32 = 42
    AURORA

    # Compile it
    result = compile_aurora_file(aurora_file)

    # Write generated files
    hpp_file = File.join(@tmpdir, "test.hpp")
    cpp_file = File.join(@tmpdir, "test.cpp")

    File.write(hpp_file, result[:header])
    File.write(cpp_file, result[:implementation])

    # Verify files exist and have content
    assert File.exist?(hpp_file), "Header file should be created"
    assert File.exist?(cpp_file), "Implementation file should be created"
    assert File.size(hpp_file) > 0, "Header should have content"
    assert File.size(cpp_file) > 0, "Implementation should have content"

    # Verify content
    hpp_content = File.read(hpp_file)
    assert_includes hpp_content, "#ifndef"
    assert_includes hpp_content, "int hello();"

    cpp_content = File.read(cpp_file)
    # Note: module name defaults to "main" without explicit module declaration
    assert_includes cpp_content, '#include "main.hpp"'
    assert_includes cpp_content, "return 42"
  end

  private

  def compile_aurora_file(path)
    source = File.read(path)
    MLC.to_hpp_cpp(source)
  end
end

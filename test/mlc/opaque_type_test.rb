# frozen_string_literal: true

require_relative '../test_helper'

class OpaqueTypeTest < Minitest::Test
  def test_opaque_type_parsing
    source = <<~AURORA
      export type Window
      export type DrawContext
    AURORA

    ast = MLC.parse(source)

    assert_equal 2, ast.declarations.length

    window_decl = ast.declarations[0]
    assert_instance_of MLC::AST::TypeDecl, window_decl
    assert_equal "Window", window_decl.name
    assert_instance_of MLC::AST::OpaqueType, window_decl.type
    assert window_decl.exported

    ctx_decl = ast.declarations[1]
    assert_instance_of MLC::AST::TypeDecl, ctx_decl
    assert_equal "DrawContext", ctx_decl.name
    assert_instance_of MLC::AST::OpaqueType, ctx_decl.type
  end

  def test_opaque_type_core_ir_transformation
    source = <<~AURORA
      type MyOpaqueType
    AURORA

    ast = MLC.parse(source)
    core_ir, type_registry = MLC.transform_to_core_with_registry(ast)

    # Type should be registered in TypeRegistry
    assert type_registry.has_type?("MyOpaqueType")

    type_info = type_registry.lookup("MyOpaqueType")
    assert type_info.opaque?

    # HighIR type should be OpaqueType
    assert_instance_of MLC::HighIR::OpaqueType, type_info.core_ir_type
  end

  def test_opaque_type_cpp_name_without_namespace
    source = <<~AURORA
      type Handle
    AURORA

    ast = MLC.parse(source)
    core_ir, type_registry = MLC.transform_to_core_with_registry(ast)

    # Without namespace, opaque type should be "Handle*"
    cpp_name = type_registry.cpp_name("Handle")
    assert_equal "Handle*", cpp_name
  end

  def test_opaque_type_cpp_lowering
    source = <<~AURORA
      type Handle

      extern fn create_handle() -> Handle
      extern fn use_handle(h: Handle) -> void

      fn test() -> void = do
        let h = create_handle();
        use_handle(h)
      end
    AURORA

    cpp = MLC.compile(source).to_source

    # Function should use Handle* pointer type
    assert_match /Handle\*/, cpp
    assert_match /Handle\* h/, cpp
    assert_match /create_handle\(\)/, cpp
    assert_match /use_handle\(h\)/, cpp
  end

  def test_opaque_type_in_stdlib
    source = <<~AURORA
      import { Window, create_window } from "Graphics"

      fn test() -> Window =
        create_window(800, 600, "Test")
    AURORA

    cpp = MLC.compile(source).to_source

    # Window should be opaque pointer type with namespace
    assert_match /aurora::graphics::Window\*/, cpp
    assert_match /aurora::graphics::create_window/, cpp
  end

  def test_opaque_type_vs_record_type
    source = <<~AURORA
      // Opaque type (no definition)
      export type Handle

      // Record type (with definition)
      export type Point = {
        x: i32,
        y: i32
      }

      extern fn get_handle() -> Handle
      extern fn get_point() -> Point
    AURORA

    ast = MLC.parse(source)
    core_ir, type_registry = MLC.transform_to_core_with_registry(ast)

    # Handle should be opaque
    handle_info = type_registry.lookup("Handle")
    assert handle_info.opaque?
    assert_equal "Handle*", handle_info.cpp_name

    # Point should be record
    point_info = type_registry.lookup("Point")
    assert point_info.record?
    assert_equal "Point", point_info.cpp_name
  end

  def test_opaque_type_builder
    opaque = MLC::HighIR::Builder.opaque_type("MyType")

    assert_instance_of MLC::HighIR::OpaqueType, opaque
    assert_equal "MyType", opaque.name
    assert opaque.opaque?
    assert_equal :opaque, opaque.kind
  end
end

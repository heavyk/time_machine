defmodule TimeMachineTest do
  use ExUnit.Case
  doctest TimeMachine

  test "TestTemplates.templates() enumerates its templates" do
    assert :tpl_logic_if in TestTemplates.templates()
    assert :tpl_logic_mixed in TestTemplates.templates()
    assert :tpl_logic_multi_obv in TestTemplates.templates()
    assert :tpl_logic_multi_obv_var in TestTemplates.templates()
    assert :tpl_logic_multi_var in TestTemplates.templates()
  end

  test "TestTemplates.panels() enumerates its panels" do
    assert :pnl_obv_assign in TestTemplates.panels()
    assert :pnl_logic_obv in TestTemplates.panels()
    assert :pnl_logic_obv_var in TestTemplates.panels()
    assert :pnl_logic_var in TestTemplates.panels()
  end

  test "TestTemplates.components() enumerates its components" do
    assert :foto in TestTemplates.components()
  end
end

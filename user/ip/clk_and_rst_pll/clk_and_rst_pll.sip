set_global_assignment -entity "clk_and_rst_pll" -library "lib_clk_and_rst_pll" -name IP_TOOL_NAME "altera_pll"
set_global_assignment -entity "clk_and_rst_pll" -library "lib_clk_and_rst_pll" -name IP_TOOL_VERSION "18.1"
set_global_assignment -entity "clk_and_rst_pll" -library "lib_clk_and_rst_pll" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_clk_and_rst_pll" -name SPD_FILE [file join $::quartus(sip_path) "clk_and_rst_pll.spd"]

set_global_assignment -library "lib_clk_and_rst_pll" -name MISC_FILE [file join $::quartus(sip_path) "clk_and_rst_pll_sim/clk_and_rst_pll.vo"]

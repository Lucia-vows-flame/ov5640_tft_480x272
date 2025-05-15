`timescale 1ns/1ns
module tb_clk_and_rst();

reg i_clk;
reg i_rst_n;

// outports wire
wire   	clk25m;
wire   	clk100m;
wire   	clk100m_2;
wire   	sys_rst_n;

clk_and_rst u_clk_and_rst(
	.i_clk     	( i_clk      ),
	.i_rst_n   	( i_rst_n    ),
	.clk25m    	( clk25m     ),
	.clk100m   	( clk100m    ),
	.clk100m_2 	( clk100m_2  ),
	.sys_rst_n 	( sys_rst_n  )
);

// clk signal
initial begin
        i_clk = 1'b1;
end
always #10 i_clk = ~i_clk;

// rst_n signal
initial begin
        i_rst_n = 1'b0;
        #100;
        i_rst_n = 1'b1;
end

endmodule
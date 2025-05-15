`include "C:\clk_and_rst\user\ip\clk_and_rst_pll\clk_and_rst_pll.v"
module clk_and_rst
(
        input           i_clk           ,
        input           i_rst_n         ,
        output          clk_9m          ,
        output          clk_100m        ,
        output          clk_100m_2      ,
        output          sys_rst_n
);

reg             rst_r1;
reg             rst_r2;
reg             sys_rst_r1;
reg             sys_rst_r2;

wire            pll_rst_n;
wire            sys_rst_r0;

//i_rst_n的同步复位异步释放
always @(posedge i_clk or negedge i_rst_n)
        if (!i_rst_n)
                begin
                        rst_r1 <= 1'b1;
                        rst_r2 <= 1'b1;
                end
        else
                begin
                        rst_r1 <= 1'b0;
                        rst_r2 <= rst_r1;
                end
assign pll_rst_n = rst_r2; //pll是高电平复位

// output declaration of module clk_and_rst_pll
wire outclk_0;
wire outclk_1;
wire outclk_2;
wire locked;

clk_and_rst_pll u_clk_and_rst_pll(
        .inclk0   	(i_clk     ),
        .areset      	(pll_rst_n ),
        .c0 	        (outclk_0  ),
        .c1 	        (outclk_1  ),
        .c2 	        (outclk_2  ),
        .locked   	(locked    )
);

assign clk_9m  = outclk_0;
assign clk_100m = outclk_1;
assign clk_100m_2 = outclk_2;

//sys_rst_n的异步复位同步释放
assign sys_rst_r0 = i_rst_n & locked;
always @(posedge clk_100m or negedge sys_rst_r0)
        if (!sys_rst_r0)
                begin
                        sys_rst_r1 <= 1'b0;
                        sys_rst_r2 <= 1'b0;
                end
        else
                begin
                        sys_rst_r1 <= 1'b1;
                        sys_rst_r2 <= sys_rst_r1;
                end
assign sys_rst_n = sys_rst_r2;

endmodule
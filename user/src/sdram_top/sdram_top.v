/*
在 sdram_interface 的基础上使用 sdram_fifo 进行读写缓存和跨时钟域处理
*/
module sdram_top
(
        input                   i_sysclk                , // system clock
        input                   sdram_clk_in            , // sdram physical chip clock input
        input                   i_sysrst_n              , // system reset signal
        //write fifo
        input                   wr_fifo_wr_clk          , // the write clock of the write fifo
        input                   wr_fifo_wr_req          , // the write request of the write fifo
        input   [15:0]          wr_fifo_wr_data         , // the write data of the write fifo
        input   [23:0]          sdram_wr_b_addr         , // first address to write sdram
        input   [23:0]          sdram_wr_e_addr         , // last address to write sdram
        input   [9:0]           wr_burst_len            , // burst length to write sdram
        input                   wr_rst                  , // reset signal of the write operation
        // read fifo
        input                   rd_fifo_rd_clk          , // the read clock of the read fifo
        input                   rd_fifo_rd_req          , // the read request of the read fifo
        input   [23:0]          sdram_rd_b_addr         , // first address to read sdram
        input   [23:0]          sdram_rd_e_addr         , // last address to read sdram
        input   [9:0]           rd_burst_len            , // burst length to read sdram
        input                   rd_rst                  , // reset signal of the read operation
        output  [15:0]          rd_fifo_rd_data         , // the read data of the read fifo
        output  [9:0]           rd_fifo_num             , // the number of data in the read fifo
	// user control signal
        input                   read_valid              , // read enable signal
        output                  init_end                , // initialization end flag
	input		        pingpang_enable         , // pingpang enable signal
        // sdram interface signal
        output                  sdram_clk_out           , // sdram physical chip clock output
        output                  sdram_cke               , // sdram clock enable
        output                  sdram_cs_n              , // sdram chip select
        output                  sdram_ras_n             , // sdram row address strobe
        output                  sdram_cas_n             , // sdram column address strobe
        output                  sdram_we_n              , // sdram write enable
        output  [1:0]           sdram_ba                , // sdram bank address
        output  [12:0]          sdram_addr              , // sdram address bus
        output  [1:0]           sdram_dqm               , // sdram data mask
        inout   [15:0]          sdram_dq                  // sdram data bus
);

//internal signals
// wire define
wire            sdram_wr_req        ; // sdram write request signal
wire            sdram_wr_ack        ; // sdram write acknowledge signal
wire    [23:0]  sdram_wr_addr       ; // sdram write address signal
wire    [15:0]  sdram_data_in       ; // sdram data input signal
wire            sdram_rd_req        ; // sdram read request signal
wire            sdram_rd_ack        ; // sdram read acknowledge signal
wire    [23:0]  sdram_rd_addr       ; // sdram read address signal
wire    [15:0]  sdram_data_out      ; // sdram data output signal

// sdram physical chip clock
assign  sdram_clk_out = sdram_clk_in;
// sdram data mask
assign  sdram_dqm = 2'b00;

//************************Instantiation************************//
// sdram_wr_rd_fifo
sdram_wr_rd_fifo u_sdram_wr_rd_fifo(
        // system signal
	.i_sysclk        	( i_sysclk         ),
	.i_sysrst_n      	( i_sysrst_n       ),
        // write fifo signal
	.wr_fifo_wr_clk  	( wr_fifo_wr_clk   ),
	.wr_fifo_wr_req  	( wr_fifo_wr_req   ),
	.wr_fifo_wr_data 	( wr_fifo_wr_data  ),
	.sdram_wr_b_addr 	( sdram_wr_b_addr  ),
	.sdram_wr_e_addr 	( sdram_wr_e_addr  ),
	.wr_burst_len    	( wr_burst_len     ),
	.wr_rst          	( wr_rst           ),
        // read fifo signal
	.rd_fifo_rd_clk  	( rd_fifo_rd_clk   ),
	.rd_fifo_rd_req  	( rd_fifo_rd_req   ),
	.sdram_rd_b_addr 	( sdram_rd_b_addr  ),
	.sdram_rd_e_addr 	( sdram_rd_e_addr  ),
	.rd_burst_len    	( rd_burst_len     ),
	.rd_rst          	( rd_rst           ),
	.rd_fifo_rd_data 	( rd_fifo_rd_data  ),
	.rd_fifo_num     	( rd_fifo_num      ),
        // user ctrl signal
	.read_valid      	( read_valid       ),
	.init_end        	( init_end         ),
        // sdram ctrl of write signal
	.sdram_wr_ack    	( sdram_wr_ack     ),
	.sdram_wr_req    	( sdram_wr_req     ),
	.sdram_wr_addr   	( sdram_wr_addr    ),
	.sdram_data_in   	( sdram_data_in    ),
        // sdram ctrl of read signal
	.sdram_rd_ack    	( sdram_rd_ack     ),
	.sdram_rd_req    	( sdram_rd_req     ),
	.sdram_rd_addr   	( sdram_rd_addr    ),
	.sdram_data_out  	( sdram_data_out   )
);

// sdram_interface
sdram_interface u_sdram_interface(
        // system signal
	.i_sysclk       	( i_sysclk        ),
	.i_sysrst_n     	( i_sysrst_n      ),
        // sdram initialization signal
	.o_init_done    	( init_end        ),
        // sdram write port
	.i_wr_req       	( sdram_wr_req    ),
	.i_wr_addr      	( sdram_wr_addr   ),
	.i_wr_burst_len 	( wr_burst_len    ),
	.i_wr_data      	( sdram_data_in   ),
	.o_wr_ack       	( sdram_wr_ack    ),
        // sdram read port
	.i_rd_req       	( sdram_rd_req    ),
	.i_rd_addr      	( sdram_rd_addr   ),
	.i_rd_burst_len 	( rd_burst_len    ),
	.o_rd_data      	( sdram_data_out  ),
	.o_rd_ack       	( sdram_rd_ack    ),
        // sdram physical chip interface
	.o_sdram_cke    	( sdram_cke       ),
	.o_sdram_cs_n   	( sdram_cs_n      ),
	.o_sdram_cas_n  	( sdram_cas_n     ),
	.o_sdram_ras_n  	( sdram_ras_n     ),
	.o_sdram_we_n   	( sdram_we_n      ),
	.o_sdram_ba     	( sdram_ba        ),
	.o_sdram_addr   	( sdram_addr      ),
	.sdram_dq       	( sdram_dq        )
);

endmodule
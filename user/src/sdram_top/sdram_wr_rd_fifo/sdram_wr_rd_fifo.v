`include "C:\image_collecting_system\user\ip\sdram_fifo\sdram_fifo.v"
module sdram_wr_rd_fifo
(
        input                   i_sysclk                , // system clock
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
        input                   init_end                , // initialization end flag
        input                   pingpang_en             , // pingpang operation enable signal
        // sdram write signal
        input                   sdram_wr_ack           , // sdram write acknowledge signal
        output                  sdram_wr_req           , // sdram write request signal
        output  [23:0]          sdram_wr_addr          , // sdram write address signal
        output  [15:0]          sdram_data_in          , // sdram data input signal
        // sdram read signal
        input                   sdram_rd_ack           , // sdram read acknowledge signal
        output                  sdram_rd_req           , // sdram read request signal
        output  [23:0]          sdram_rd_addr          , // sdram read address signal
        input   [15:0]          sdram_data_out           // sdram data output signal
);

// outports
reg                     r_sdram_wr_req        ; // sdram write request signal
reg     [23:0]          r_sdram_wr_addr       ; // sdram write address signal
reg                     r_sdram_rd_req        ; // sdram read request signal
reg     [23:0]          r_sdram_rd_addr       ; // sdram read address signal
assign  sdram_wr_req       = r_sdram_wr_req       ;
assign  sdram_wr_addr      = r_sdram_wr_addr      ;
assign  sdram_rd_req       = r_sdram_rd_req       ;
assign  sdram_rd_addr      = r_sdram_rd_addr      ;

// internal signals
// wire define
wire            wr_ack_fall     ; // write acknowledge falling edge
wire            rd_ack_fall     ; // read acknowledge falling edge
wire    [9:0]   wr_fifo_num     ; // the number of data in the write fifo
// reg define
reg             wr_ack_dly      ; // write acknowledge delay signal
reg             rd_ack_dly      ; // read acknowledge delay signal
// pingpang operation reg define
reg             bank_en         ; // Bank switch enable signal
reg             bank_flag       ; // Address of Bank switch flag signal

//*****************************Main Code*****************************//
// wr_ack_dly
always @(posedge i_sysclk or negedge i_sysrst_n)
        if(!i_sysrst_n)
                wr_ack_dly <= 1'b0;
        else
                wr_ack_dly <= sdram_wr_ack;

// rd_ack_dly
always @(posedge i_sysclk or negedge i_sysrst_n)
        if(!i_sysrst_n)
                rd_ack_dly <= 1'b0;
        else
                rd_ack_dly <= sdram_rd_ack;

// wr_ack_fall
assign  wr_ack_fall = wr_ack_dly & ~sdram_wr_ack;
// rd_ack_fall
assign  rd_ack_fall = rd_ack_dly & ~sdram_rd_ack;

// bank_en,bank_flag : Bank switch enable signal, read or write Bank flag signal
always @(posedge i_sysclk or negedge i_sysrst_n)
        if(!i_sysrst_n)
                begin
                        bank_en <= 1'b0;
                        bank_flag <= 1'b0;
                end
        else if((wr_ack_fall) && (pingpang_en)) // if write acknowledge falling edge is valid and pingpang operation is enabled, we can switch the bank
                if(sdram_wr_addr[21:0] < (sdram_wr_e_addr - wr_burst_len)) // if sdram_wr_addr is less than (sdram_wr_e_addr - wr_burst_len)
                        begin
                                bank_en <= bank_en;
                                bank_flag <= bank_flag;
                        end
                else // if sdram_wr_addr is greater than or equal to (sdram_wr_e_addr - wr_burst_len)
                        begin
                                bank_en <= 1'b1;         // switch the bank
                                bank_flag <= ~bank_flag; // switch the address of Bank flag
                        end
        else if(bank_en)
                begin
                        bank_en <= 1'b0;
                        bank_flag <= bank_flag;
                end

// sdram_wr_addr : the sdram write address signal
always @(posedge i_sysclk or negedge i_sysrst_n)
        if(!i_sysrst_n)
                r_sdram_wr_addr <= 24'd0;
        else if(wr_rst) // r_sdram_wr_addr is setted as sdram_wr_b_addr when wr_rst is valid
                r_sdram_wr_addr <= sdram_wr_b_addr;
        else if(wr_ack_fall) // if wr_ack_fall is valid, a burst write operation is finished
                if((pingpang_en) && (sdram_wr_addr[21:0] < (sdram_wr_e_addr - wr_burst_len)))
                        r_sdram_wr_addr <= r_sdram_wr_addr + wr_burst_len;
                else if(r_sdram_wr_addr < (sdram_wr_e_addr - wr_burst_len)) // if r_sdram_wr_addr is not (sdram_wr_e_addr - wr_burst_len), we didn't write all the data we wanted to write. So r_sdram_wr_addr is increased by wr_burst_len
                        r_sdram_wr_addr <= r_sdram_wr_addr + wr_burst_len;
                else // if r_sdram_wr_addr is (sdram_wr_e_addr - wr_burst_len), we have written all the data we wanted to write. So r_sdram_wr_addr is setted as sdram_wr_b_addr
                        r_sdram_wr_addr <= sdram_wr_b_addr;
        else if(bank_en) // if bank_en is valid, we can switch the bank
                if(!bank_flag) // if bank_flag is 0, we will switch to bank 0
                        r_sdram_wr_addr <= {2'b00, r_sdram_wr_addr[21:0]}; // set the bank address to 0
                else // if bank_flag is 1, we can switch to bank 1
                        r_sdram_wr_addr <= {2'b01, r_sdram_wr_addr[21:0]}; // set the bank address to 1

// sdram_rd_addr : the sdram read address signal
always @(posedge i_sysclk or negedge i_sysrst_n)
        if(!i_sysrst_n)
                r_sdram_rd_addr <= 24'd0;
        else if(rd_rst) // r_sdram_rd_addr is setted as sdram_rd_b_addr when rd_rst is valid
                r_sdram_rd_addr <= sdram_rd_b_addr;
        else if(rd_ack_fall) // if rd_ack_fall is valid, a burst read operation is finished
                if(pingpang_en)
                        if(sdram_rd_addr[21:0] < (sdram_rd_e_addr - rd_burst_len))
                                r_sdram_rd_addr <= r_sdram_rd_addr + rd_burst_len;
                        else // Note that the Bank switch for a read operation should be the opposite of the Bank switch for a write operation.
                                if(!bank_flag) // if bank_flag is 0, we will switch to bank 1
                                        r_sdram_rd_addr <= {2'b01, r_sdram_rd_addr[21:0]}; // set the bank address to 0
                                else // if bank_flag is 1, we can switch to bank 0
                                        r_sdram_rd_addr <= {2'b00, r_sdram_rd_addr[21:0]}; // set the bank address to 1
                else if(r_sdram_rd_addr < (sdram_rd_e_addr - rd_burst_len)) // if r_sdram_rd_addr is not (sdram_rd_e_addr - rd_burst_len), we didn't read all the data we wanted to read. So r_sdram_rd_addr is increased by rd_burst_len
                        r_sdram_rd_addr <= r_sdram_rd_addr + rd_burst_len;
                else // if r_sdram_rd_addr is (sdram_rd_e_addr - rd_burst_len), we have read all the data we wanted to read. So r_sdram_rd_addr is setted as sdram_rd_b_addr
                        r_sdram_rd_addr <= sdram_rd_b_addr;

// sdram_wr_req : the sdram write request signal
always @(posedge i_sysclk or negedge i_sysrst_n)
        if(!i_sysrst_n)
                r_sdram_wr_req <= 1'b0;
        else if(init_end)
                if(wr_fifo_num >= wr_burst_len) // if the number of data in the write fifo is greater than or equal to wr_burst_len, we can send a write request to sdram. Meanwhile, we can't read data from sdram
                        r_sdram_wr_req <= 1'b1;
                else if((rd_fifo_num < rd_burst_len) && (read_valid)) // if the number of data in the read fifo is less than rd_burst_len and read_valid is valid, we can send a write request to sdram. Meanwhile, we can't read data from sdram
                        r_sdram_wr_req <= 1'b0;
                else // In other cases, write request is setted as 0
                        r_sdram_wr_req <= 1'b0;
        else // if init_end is not valid, write request is setted as 0
                r_sdram_wr_req <= 1'b0;
// sdram_rd_req : the sdram read request signal
always @(posedge i_sysclk or negedge i_sysrst_n)
        if(!i_sysrst_n)
                r_sdram_rd_req <= 1'b0;
        else if(init_end)
                if(wr_fifo_num >= wr_burst_len) // if the number of data in the write fifo is greater than or equal to wr_burst_len, we can send a read request to sdram. Meanwhile, we can't read data from sdram
                        r_sdram_rd_req <= 1'b0;
                else if((rd_fifo_num < rd_burst_len) && (read_valid)) // if the number of data in the read fifo is less than rd_burst_len and read_valid is valid, we can send a read request to sdram. Meanwhile, we can't read data from sdram
                        r_sdram_rd_req <= 1'b1;
                else // In other cases, read request is setted as 0
                        r_sdram_rd_req <= 1'b0;
        else // if init_end is not valid, read request is setted as 0
                r_sdram_rd_req <= 1'b0;

//*********************************Instantiation*******************************//
// write fifo
// write fifo clear signal
wire    wr_fifo_clr = (wr_rst || ~i_sysrst_n);
sdram_fifo	wr_fifo
(
        // user interface
	.data    (wr_fifo_wr_data),
	.wrclk   (wr_fifo_wr_clk ),
	.wrreq   (wr_fifo_wr_req ),
        // sdram interface        
	.rdclk   (i_sysclk       ),
	.rdreq   (sdram_wr_ack   ),
	.q       (sdram_data_in  ),

        .aclr    (wr_fifo_clr    ),
	.rdusedw (wr_fifo_num    ),
	.wrusedw (               )
);
// read fifo
// read fifo clear signal
wire    rd_fifo_clr = (rd_rst || ~i_sysrst_n);
sdram_fifo	rd_fifo
(
        // sdram interface
	.data    (sdram_data_out ),
	.wrclk   (i_sysclk       ),
	.wrreq   (sdram_rd_ack   ),
        // user interface        
	.rdclk   (rd_fifo_rd_clk ),
	.rdreq   (rd_fifo_rd_req ),
	.q       (rd_fifo_rd_data),

        .aclr    (rd_fifo_clr    ),
	.rdusedw (               ),
	.wrusedw (rd_fifo_num    )
);
endmodule
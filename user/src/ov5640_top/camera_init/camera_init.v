module camera_init
#(
        parameter       CAMERA_TYPE = "ov5640",
        parameter       IMAGE_TYPE = 0, // 0: RGB, 1: JPEG
        parameter       IMAGE_WIDTH = 480,
        parameter       IMAGE_HEIGHT = 272,
        parameter       IMAGE_FLIP_EN = 0,
        parameter       IMAGE_MIRROR_EN = 0
)
(
        input           i_sysclk,
        input           i_sysrst_n,

        output          init_done,
        output          camera_rst_n,
        output          camera_pwdn,

        output          iic_sclk,
        inout           iic_sdat
);

// output ports
reg     r_init_done;
assign  init_done = r_init_done;

localparam RGB = 0;
localparam JPEG = 1;


// iic_control 例化
// outports wire
wire    [15:0]  addr;
wire    [7:0]   wr_data;
wire    [7:0]  	rd_data;
wire        	rw_done;
wire        	ack;
wire    [7:0]   device_id;
reg        	wrreg_req;
// reg        	rdreg_req; // 读寄存器请求信号，暂时不使用，因为配置寄存器不需要读操作
reg     [31:0]  iic_dly_cnt_max; // 写在前面，因为iic_control例化时需要使用，如果写在后面，会报错重复声明; 该 reg 用于软件复位的延时等待
iic_control u_iic_control(
	.i_sysclk   	( i_sysclk    ),
	.i_sysrst_n 	( i_sysrst_n  ),
	.wrreg_req  	( wrreg_req   ),
	.rdreg_req  	( 0           ), // 读寄存器请求信号，暂时不使用，因为配置寄存器不需要读操作
	.addr       	( addr        ),
	.addr_mode  	( addr_mode   ),
	.wr_data    	( wr_data     ),
	.rd_data    	( rd_data     ),
	.device_id  	( device_id   ),
	.rw_done    	( rw_done     ),
	.ack        	( ack         ),
        .dly_cnt_max    ( iic_dly_cnt_max),
	.iic_sclk   	( iic_sclk    ),
	.iic_sdat   	( iic_sdat    )
);

// reg definitions

reg     [7:0]   rom_addr; //RTL_ROM的地址计算寄存器
reg     [20:0]  delay_cnt; //延时计数器，上电复位后，需要延迟一定的时间才能进行寄存器配置

// wire definitions
wire    [23:0]  rom_out; //RTL_ROM的输出数据
wire    [7:0]   rom_out_size; //RTL_ROM的最终输出数据量
wire            camera_init_go; // camera_init的使能信号

assign camera_pwdn = 1'b0; // camera power down
//不使用硬件复位，该信号一直拉低

generate
        if (CAMERA_TYPE == "ov5640")
                begin
                        assign device_id = 8'h78;
                        assign addr_mode = 1'b1;
                        assign addr = rom_out[23:8];
                        assign wr_data = rom_out[7:0];

                        if (IMAGE_TYPE == RGB)
                                begin
                                        assign rom_out_size = 8'd252;
                                        ov5640_init_table_rgb
                                        #(
                                                .IMAGE_WIDTH     	(IMAGE_WIDTH    ),
                                                .IMAGE_HEIGHT    	(IMAGE_HEIGHT   ),
                                                .IMAGE_FLIP_EN   	(IMAGE_FLIP_EN  ),
                                                .IMAGE_MIRROR_EN 	(IMAGE_MIRROR_EN)
                                        )
                                        u_ov5640_init_table_rgb(
                                                .clk  	(i_sysclk  ),
                                                .addr 	(rom_addr  ),
                                                .q    	(rom_out   )
                                        );
                                        
                                end
                        else if (IMAGE_TYPE == JPEG)
                                begin
                                        assign rom_out_size = 8'd250;
                                        ov5640_init_table_jpeg
                                        #(
                                                .IMAGE_WIDTH     	(IMAGE_WIDTH    ),
                                                .IMAGE_HEIGHT    	(IMAGE_HEIGHT   ),
                                                .IMAGE_FLIP_EN   	(IMAGE_FLIP_EN  ),
                                                .IMAGE_MIRROR_EN 	(IMAGE_MIRROR_EN)
                                        )
                                        u_ov5640_init_table_jpeg(
                                                .clk  	(i_sysclk  ),
                                                .addr 	(rom_addr  ),
                                                .q    	(rom_out   )
                                        );
                                end
                end
        else if (CAMERA_TYPE == "ov7725")
                begin
                        assign device_id = 8'h42;
                        assign addr_mode = 1'b0;
                        assign addr = rom_out[15:8];
                        assign wr_data = rom_out[7:0];

                        if (IMAGE_TYPE == RGB)
                                begin
                                        assign rom_out_size = 8'd68;
                                        ov7725_init_table_rgb
                                        #(
                                                .IMAGE_WIDTH     	(IMAGE_WIDTH    ),
                                                .IMAGE_HEIGHT    	(IMAGE_HEIGHT   ),
                                                .IMAGE_FLIP_EN   	(IMAGE_FLIP_EN  ),
                                                .IMAGE_MIRROR_EN 	(IMAGE_MIRROR_EN)
                                        )
                                        u_ov7725_init_table_rgb(
                                                .clk  	(i_sysclk  ),
                                                .addr 	(rom_addr  ),
                                                .q    	(rom_out   )
                                        );
                                end
                end
endgenerate

//上电并进行硬件复位完成20ms后再配置摄像头，所以从上电到开始配置应该是1.0034 + 20 = 21.0034ms
//这里为了优化逻辑，简化比较器逻辑，直接使延迟比较值为24'h100800，是21.0125ms
//只有在延时计数器计数到21.0125ms时，才能产生开始信号
always@(posedge i_sysclk or negedge i_sysrst_n)
        if (!i_sysrst_n)
                delay_cnt <= 21'd0;
        else if (delay_cnt == 21'h100800)
                delay_cnt <= 21'd100800; //延迟计数器上电后如果不复位，则用不清零
        else
                delay_cnt <= delay_cnt + 1'b1;

//当延时时间到，开始使能初始化模块对OV5640的寄存器进行写入  
assign camera_init_go = (delay_cnt == 21'h1007ff) ? 1'b1 : 1'b0; //产生开始信号（握手信号）

//5640要求上电后其复位状态需要保持1ms，所以上电后需要1ms之后再使能释放摄像头的复位信号
//这里为了优化逻辑，简化比较器逻辑，直接使延迟比较值为24'hC400，是1.003520ms
//assign camera_rst_n = (delay_cnt > 21'hC400);
assign camera_rst_n = 1; // 硬件复位，不使用，直接拉高，我们使用寄存器进行复位
//delay_cnt 只用于产生开始信号，不产生硬件复位，我们在这里不会使用硬件复位

// RTL_ROM的地址计算
always@(posedge i_sysclk or negedge i_sysrst_n)
        if (!i_sysrst_n)
                rom_addr <= 8'd0;
        else if (camera_init_go)
                rom_addr <= 8'd0;
        else if (rom_addr < rom_out_size)
                if (rw_done && (!ack)) // IIC完成写入，且 ack 信号为低电平，表示写入成功
                        rom_addr <= rom_addr + 1'b1;
                else
                        rom_addr <= rom_addr;
        else
                rom_addr <= 8'd0;

// camera 初始化完成信号 init_done
always@(posedge i_sysclk or negedge i_sysrst_n)
        if (!i_sysrst_n)
                r_init_done <= 1'b0;
        else if (camera_init_go) //初始化开始时，将初始化完成信号置为0
                r_init_done <= 1'b0;
        else if (rom_addr == rom_out_size) //只有 rom_out_size - 1 个寄存器，但 rom_addr 会计数到 rom_out_size，这个段时刻恰好可以作为初始化完成的标志
                r_init_done <= 1'b1;
        else
                r_init_done <= 1'b0;
assign init_done = r_init_done;

// camera 寄存器配置状态机
reg     [1:0]   cstate;
reg     [1:0]   nstate;
/*
| 状态 | 说明 |
| 0    |初始状态，等待开始信号|
| 1    |寄存器写入状态，等待IIC完成写入|
| 2    |寄存器写入等待状态，等待IIC完成写入|
*/
// first section
always @(posedge i_sysclk or negedge i_sysrst_n)
        if (!i_sysrst_n)
                cstate <= 2'b00;
        else
                cstate <= nstate;
// second section
always @(*)
        if (rom_addr < rom_out_size)
                case (cstate)
                        0: // 初始状态，等待开始信号
                                if (camera_init_go)
                                        nstate = 2'b01;
                                else
                                        nstate = 2'b00;
                        1: // 寄存器写入状态
                                nstate = 2'b10;
                        2: // 寄存器写入等待状态，等待IIC完成写入
                                if (rw_done)
                                        nstate = 2'b01;
                                else
                                        nstate = 2'b10;
                        default:
                                nstate = 2'b00;
                endcase
        else
                nstate = 2'b00;
// third section
always @(posedge i_sysclk or negedge i_sysrst_n)
        if (!i_sysrst_n)
                wrreg_req <= 1'b0;
        else if ((rom_addr < rom_out_size) && (cstate == 2'b01))
                wrreg_req <= 1'b1;
        else
                wrreg_req <= 1'b0;
always @(posedge i_sysclk or negedge i_sysrst_n)
        if (!i_sysrst_n)
                iic_dly_cnt_max <= 32'd0;
        else if ((rom_addr < rom_out_size) && (cstate == 2'b01))
                if (rom_addr == 1) // rom_addr == 1 对应的寄存器地址就是软件复位寄存器
                        iic_dly_cnt_max <= 32'h40000; // 在进行软件复位后，需要延时2~5ms才能进行其他寄存器的写入，这里使用了5ms
                else
                        iic_dly_cnt_max <= 32'd0;

endmodule
module iic_control
(
        //system signals
        input           i_sysclk,
        input           i_sysrst_n,

        input    [31:0] dly_cnt_max, //延时计数器最大值

        input           wrreg_req, //寄存器写请求
        input           rdreg_req, //寄存器读请求
        input    [15:0] addr,      //寄存器地址 1byte or 2byte
        input           addr_mode, //寄存器地址模式: 1byte or 2byte
        input    [7:0]  wr_data,   //要写入的数据
        output   [7:0]  rd_data,   //要读取的数据
        input    [7:0]  device_id, //设备ID
        output          rw_done,   //读写完成信号
        //输出应答信号
        output          ack,
        //iic bus signals
        output          iic_sclk,
        inout           iic_sdat
);

//output ports
reg     [7:0]   r_rddata;
reg             r_rw_done;
reg             r_ack;
assign rd_data = r_rddata;
assign rw_done = r_rw_done;
assign ack     = r_ack;

//reg definitions
reg     [5:0]   cmd; //命令寄存器
reg     [7:0]   tx_data; //要写入的数据
reg             go; //开始传输信号
reg     [7:0]   cnt; //计数器
reg     [31:0]  dly_cnt; //延时计数器

//wire definitions
wire    [15:0]  reg_addr; //缓存寄存器地址并选择寄存器地址模式


//地址模式选择
assign reg_addr = addr_mode ? addr : {addr[7:0], addr[15:8]}; //addr_mode == 1 ：2byte地址模式，addr_mode == 0：1byte地址模式

//命令定义
localparam      WR   = 6'b000001; //写命令
localparam      STA  = 6'b000010; //产生起始位
localparam      RD   = 6'b000100; //读命令
localparam      STO  = 6'b001000; //产生停止位
localparam      ACK  = 6'b010000; //产生应答位
localparam      NACK = 6'b100000; //产生非应答位

//iic_tim_gen 实例化
// outports wire
wire       	o_ack; //输出应答信号，便于用户查错
wire    [7:0]   rx_data;  //要读取的数据
wire       	trans_done; //传输完成信号

iic_tim_gen u_iic_tim_gen
(
	.i_sysclk    	( i_sysclk     ),
	.i_sysrst_n  	( i_sysrst_n   ),
	.i_cmd       	( cmd          ),
	.i_tx_data   	( tx_data      ),
	.i_iic_start 	( go           ),
	.iic_sda     	( iic_sdat     ),
	.o_iic_scl   	( iic_sclk     ),
	.o_ack       	( o_ack        ),
	.o_rx_data   	( rx_data      ),
	.o_iic_done  	( trans_done   )
);


//状态参数定义
localparam      IDLE = 8'b00000001; //空闲状态
localparam      WR_REG = 8'b00000010; //写寄存器状态
localparam      WAIT_WR_DONE = 8'b00000100; //等待写寄存器完成状态
localparam      WR_REG_DONE = 8'b00001000; //写寄存器完成状态
localparam      RD_REG = 8'b00010000; //读寄存器状态
localparam      WAIT_RD_DONE = 8'b00100000; //等待读寄存器完成状态
localparam      RD_REG_DONE = 8'b01000000; //读寄存器完成状态
localparam      WAIT_DLY = 8'b10000000; //等待延时状态

//状态机
reg     [6:0]   cstate; //当前状态
reg     [6:0]   nstate; //下一个状态
//first section
always @(posedge i_sysclk or negedge i_sysrst_n)
        if(!i_sysrst_n)
                cstate <= IDLE;
        else
                cstate <= nstate;
//second section
always @(*)
        if(!i_sysrst_n)
                nstate = IDLE;
        else
                case(cstate)
                        IDLE:
                                if(wrreg_req)
                                        nstate = WR_REG;
                                else if(rdreg_req)
                                        nstate = RD_REG;
                                else
                                        nstate = IDLE;
                        WR_REG:
                                nstate = WAIT_WR_DONE;
                        WAIT_WR_DONE:
                                if(trans_done)
                                        case (cnt)
                                                0,1,2:
                                                        nstate = WR_REG;
                                                3:
                                                        nstate = WR_REG_DONE;
                                                default:
                                                        nstate = IDLE;
                                        endcase
                        WR_REG_DONE:
                                // nstate = IDLE; //普通的 IIC 写成后，直接回到空闲状态
                                nstate = WAIT_DLY; //写完成后，进入等待延时状态
                        RD_REG:
                                nstate = WAIT_RD_DONE;
                        WAIT_RD_DONE:
                                if(trans_done)
                                        case (cnt)
                                                0,1,2,3:
                                                        nstate = RD_REG;
                                                4:
                                                        nstate = RD_REG_DONE;
                                                default:
                                                        nstate = IDLE;
                                        endcase
                        RD_REG_DONE:
                                // nstate = IDLE; //普通的 IIC 读完成后，直接回到空闲状态
                                nstate = WAIT_DLY; //读完成后，进入等待延时状态
                        WAIT_DLY:
                                if(dly_cnt <= dly_cnt_max)
                                        nstate = WAIT_DLY; // 没有达到延时计数器最大值，继续等待
                                else
                                        nstate = IDLE;
                        default:
                                nstate = IDLE;
                endcase
//third section
always @(posedge i_sysclk or negedge i_sysrst_n)
        if(!i_sysrst_n)
                begin
                        cmd       <= 6'd0;
                        tx_data   <= 8'h00;
                        go        <= 1'b0;
                        r_ack     <= 1'b0;
                        r_rddata  <= 8'h00;
                        cnt       <= 8'd0;
                        dly_cnt   <= 32'd0;
                        r_rw_done <= 1'b0;
                end
        else
                case(cstate)
                        IDLE:
                                begin
                                        cnt    <= 8'd0;
                                        dly_cnt <= 32'd0;
                                        r_ack  <= 1'b0;
                                        r_rw_done <= 1'b0;
                                end
                        WR_REG:
                                case (cnt)
                                        0:
                                                write_byte(WR | STA, device_id); //起始位 + 写设备ID
                                        1:
                                                write_byte(WR, reg_addr[15:8]); //写寄存器地址高8位
                                        2:
                                                write_byte(WR, reg_addr[7:0]); //写寄存器地址低8位
                                        3:
                                                write_byte(WR | STO, wr_data); //写数据 + 停止位
                                        default:;
                                endcase
                        WAIT_WR_DONE:
                                begin
                                        go <= 1'b0;
                                        if(trans_done)
                                                begin
                                                        r_ack <= r_ack | o_ack; //读取应答信号
                                                        case (cnt)
                                                                0:
                                                                        cnt <= 1;
                                                                1:
                                                                        if(addr_mode)
                                                                                cnt <= 2;
                                                                        else
                                                                                cnt <= 3;
                                                                2:
                                                                        cnt <= 3;
                                                                default:;
                                                        endcase
                                                end
                                end
                        //WR_REG_DONE: // 普通的 IIC 写完成后，直接回到空闲状态
                                //r_rw_done <= 1'b1;
                        RD_REG:
                                case (cnt)
                                        0:
                                                write_byte(WR | STA, device_id); //起始位 + 写设备ID
                                        1:
                                                write_byte(WR, reg_addr[15:8]); //写寄存器地址高8位
                                        2:
                                                write_byte(WR, reg_addr[7:0]); //写寄存器地址低8位
                                        3:
                                                write_byte(WR | STA, device_id | 8'd1); //起始位 + 写设备ID
                                        4:
                                                read_byte(RD | NACK | STO); //读数据 + 非应答位 + 停止位，给非应答位代表只读取一字节数据
                                        default:;
                                endcase
                        WAIT_RD_DONE:
                                begin
                                        go <= 1'b0;
                                        if(trans_done)
                                                begin
                                                        if(cnt < 3)
                                                                r_ack <= r_ack | o_ack; //读取应答信号
                                                        case (cnt)
                                                                0:
                                                                        cnt <= 1;
                                                                1:
                                                                        if(addr_mode)
                                                                                cnt <= 2;
                                                                        else
                                                                                cnt <= 3;
                                                                2:
                                                                        cnt <= 3;
                                                                3:
                                                                        cnt <= 4;
                                                                default:;
                                                        endcase
                                                end
                                end
                        RD_REG_DONE:
                                begin
                                        //r_rw_done <= 1'b1; // 普通的 IIC 读完成后，直接回到空闲状态
                                        r_rddata <= rx_data; //读取的数据
                                end
                        WAIT_DLY: //只有在进行软件复位时，dly_cnt_max 才不为零，其他时刻都是0，不会进行延时
                                if (dly_cnt <= dly_cnt_max)
                                        dly_cnt <= dly_cnt + 1;
                                else
                                        begin
                                                dly_cnt <= 32'd0;
                                                r_rw_done <= 1'b1; //读写完成信号，等待完成后，回到空闲状态
                                        end
                        default:;
                endcase
//read task
task read_byte
(
        input [5:0] ctrl_cmd
);
        // Read a byte from the IIC bus
        // Implementation of read_byte task
        begin
                cmd <= ctrl_cmd;
                go  <= 1'b1;
        end
endtask
//write task
task write_byte
(
        input [5:0] ctrl_cmd,
        input [7:0] wr_byte_data
);
        // Write a byte to the IIC bus
        // Implementation of write_byte task
        begin
                cmd    <= ctrl_cmd;
                tx_data <= wr_byte_data;
                go     <= 1'b1;
        end
endtask


endmodule
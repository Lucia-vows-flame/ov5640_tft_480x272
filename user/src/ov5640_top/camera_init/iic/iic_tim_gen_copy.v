module iic_tim_gen_copy
(
        input   wire            i_sysclk        ,
        input   wire            i_sysrst_n      ,
        input   wire    [5:0]   i_cmd           ,
        input   wire    [7:0]   i_tx_data       ,
        input   wire            i_iic_start     ,

        inout   wire            iic_sda         ,

        output  reg             o_iic_scl       ,
        output  reg             o_ack           ,
        output  reg     [7:0]   o_rx_data       ,
        output  reg             o_iic_done       
);

//parameter definitions
parameter       SYS_CLOCK                = 50_000_000;//50MHz的系统时钟
parameter       SCL                      = 400_000;//400KHz的IIC时钟
localparam      SCL_COUNTER              = SYS_CLOCK / SCL / 4 - 1;//状态分割计数器的计数最大值
//状态定义
localparam      IDLE                     = 7'b0000001,   //空闲状态
                START                    = 7'b0000010,   //起始位
                WRITE                    = 7'b0000100,   //写状态
                READ                     = 7'b0001000,   //读状态
                CHECK_SLAVE_ACK          = 7'b0010000,   //检测从机应答
                MASTER_GENERATE_ACK      = 7'b0100000,   //主机产生应答
                STOP                     = 7'b1000000;   //停止位
//指令集定义
localparam      WR                       = 6'b000001,    //写指令
                STA                      = 6'b000010,    //起始位指令
                RD                       = 6'b000100,    //读指令
                STO                      = 6'b001000,   //停止位指令
                ACK                      = 6'b010000,    //应答指令
                NACK                     = 6'b100000;    //非应答指令

//reg definitions
reg             o_iic_sda       ;//IIC 的输出类型的 SDA 信号
reg             iic_sda_oe      ;//inout 中三态门的控制信号
reg     [19:0]  scl_counter     ;//状态分割计数器
reg             en_scl_counter  ;//状态分割计数器的使能信号
reg     [4:0]   state_counter   ;//状态记录计数器
reg     [7:0]   cstate          ;//状态机的当前状态
reg     [7:0]   nstate          ;//状态机的下一个状态

//wire definitions
wire            scl_plus        ;//状态分割计数器计满的标志信号

//状态分割计数器
always @(posedge i_sysclk or negedge i_sysrst_n)
        begin
                if (!i_sysrst_n)
                        scl_counter <= 20'd0;
                else if (en_scl_counter)
                        begin
                                if (scl_counter < SCL_COUNTER)
                                        scl_counter <= scl_counter + 1;
                                else
                                        scl_counter <= 20'd0;
                        end
        end

//scl_plus
assign  scl_plus = scl_counter == SCL_COUNTER;  //scl_counter == SCL_COUNTER时，代表一个状态分割计数器计满，此时的状态记录计数器应该自增 1

//inout 端口
assign  iic_sda = !o_iic_sda && iic_sda_oe ? 1'b0 : 1'bz;

//状态机
//first section
always @(posedge i_sysclk or negedge i_sysrst_n)
        if(!i_sysrst_n) //复位初始化
                cstate <= IDLE;
        else
                cstate <= nstate;

//second section
always @(*)
        case (cstate)
                IDLE:   //空闲状态，等待开始传输信号 i_iic_start 有效
                        if(i_iic_start) //i_iic_start 信号为高时，代表开始传输
                                if(i_cmd & STA)
                                        nstate <= START;
                                else if(i_cmd & WR)
                                        nstate <= WRITE;
                                else if(i_cmd & RD)
                                        nstate <= READ;
                                else
                                        nstate <= IDLE;
                        else
                                nstate <= IDLE;
                START: //起始位状态，产生起始位信号
                        if(scl_plus) //状态分割计数器计满一次，代表状态要进行更新
                                if(state_counter == 3)
                                        if(i_cmd & WR)
                                                nstate <= WRITE;
                                        else if(i_cmd & RD)
                                                nstate <= READ;
                                        else
                                                nstate <= IDLE;
                WRITE: //写状态，产生写数据
                        if(scl_plus) //状态分割计数器计满一次，代表状态要进行更新
                                if(state_counter == 31)
                                        nstate <= CHECK_SLAVE_ACK;
                                else
                                        nstate <= WRITE;
                READ:   //读状态，接收数据
                        if(scl_plus) //状态分割计数器计满一次，代表状态要进行更新
                                if(state_counter == 31)
                                        nstate <= MASTER_GENERATE_ACK;
                                else
                                        nstate <= READ;
                CHECK_SLAVE_ACK: //检测从机应答状态，检测从机是否应答
                        if(scl_plus) //状态分割计数器计满一次，代表状态要进行更新
                                if(state_counter == 3)
                                        if(i_cmd & STO)
                                                nstate <= STOP;
                                        else
                                                nstate <= IDLE;
                MASTER_GENERATE_ACK: //主机产生应答状态，产生应答信号
                        if(scl_plus) //状态分割计数器计满一次，代表状态要进行更新
                                if(state_counter == 3)
                                        if(i_cmd & STO)
                                                nstate <= STOP;
                                        else
                                                nstate <= IDLE;
                STOP:   //停止位状态，产生停止位信号
                        if(scl_plus) //状态分割计数器计满一次，代表状态要进行更新
                                if(state_counter == 3)
                                        nstate <= IDLE;
                default:  //默认状态，跳转到空闲状态
                        nstate <= IDLE;
        endcase

//third section
always @(posedge i_sysclk or negedge i_sysrst_n)
        if(!i_sysrst_n)
                begin
                        o_rx_data <= 8'd0;
                        iic_sda_oe <= 1'b0;
                        en_scl_counter <= 1'b1;
                        o_iic_sda <= 1'b1;
                        o_iic_done <= 1'b0;
                        o_ack <= 1'b0;
                        state_counter <= 5'd0;
                end
        else
                case (cstate)
                        IDLE:   //空闲状态，等待开始传输信号 i_iic_start 有效
                                begin
                                        o_iic_done <= 1'b0;
                                        iic_sda_oe <= 1'b1;
                                        if(i_iic_start) //i_iic_start 信号为高时，代表开始传输
                                                en_scl_counter <= 1'b1; //开始传输时，使能状态分割计数器
                                        else
                                                en_scl_counter <= 1'b0; //不传输时，禁止状态分割计数器
                                end
                        START: //起始位状态，产生起始位信号
                                if(scl_plus) //状态分割计数器计满一次，代表状态要进行更新
                                        begin
                                                if(state_counter == 3) //状态记录计数器
                                                        state_counter <= 0;
                                                else
                                                        state_counter <= state_counter + 1;
                                                case (state_counter) //线性序列机完成起始位时序
                                                        0:
                                                                begin
                                                                        o_iic_sda <= 1'b1;
                                                                        iic_sda_oe <= 1'b1;
                                                                end
                                                        1:
                                                                o_iic_scl <= 1'b1;
                                                        2:
                                                                begin
                                                                        o_iic_scl <= 1'b1;
                                                                        o_iic_sda <= 1'b0;
                                                                end
                                                        3:
                                                                o_iic_scl <= 1'b0;
                                                        default:
                                                                begin
                                                                        o_iic_scl <= 1'b1;
                                                                        o_iic_sda <= 1'b1;
                                                                end
                                                endcase
                                        end
                        WRITE: //写状态，发送数据
                                if(scl_plus) //状态分割计数器计满一次，代表状态要进行更新
                                        begin
                                                if(state_counter == 31) //状态记录计数器
                                                        state_counter <= 0;
                                                else
                                                        state_counter <= state_counter + 1;
                                                case (state_counter) //线性序列机完成写数据时序
                                                        0,4,8,12,16,20,24,28: //写数据
                                                                begin
                                                                        iic_sda_oe <= 1'b1;
                                                                        o_iic_sda <= i_tx_data[7 - state_counter[4:2]];
                                                                end
                                                        1,5,9,13,17,21,25,29: //SCL上升沿
                                                                o_iic_scl <= 1'b1;
                                                        2,6,10,14,18,22,26,30: //SCL保持高电平
                                                                o_iic_scl <= 1'b1;
                                                        3,7,11,15,19,23,27,31: //SCL下降沿
                                                                o_iic_scl <= 1'b0;
                                                        default:
                                                                begin
                                                                        o_iic_scl <= 1'b1;
                                                                        o_iic_sda <= 1'b1;
                                                                end
                                                endcase
                                        end
                        READ:   //读状态，接收数据
                                if(scl_plus) //状态分割计数器计满一次，代表状态要进行更新
                                        begin
                                                if(state_counter == 31) //状态记录计数器
                                                        state_counter <= 0;
                                                else
                                                        state_counter <= state_counter + 1;
                                                case (state_counter) //线性序列机完成读数据时序
                                                        0,4,8,12,16,20,24,28: //读出数据
                                                                begin
                                                                        iic_sda_oe <= 1'b0;
                                                                        o_iic_scl <= 1'b0;
                                                                end
                                                        1,5,9,13,17,21,25,29: //SCL上升沿
                                                                o_iic_scl <= 1'b1;
                                                        2,6,10,14,18,22,26,30: //SCL保持高电平
                                                                begin
                                                                        o_iic_scl <= 1'b1;
                                                                        o_rx_data <= {o_rx_data[6:0], iic_sda}; //7 位接收数据加 1 位应答
                                                                end
                                                        3,7,11,15,19,23,27,31: //SCL下降沿
                                                                o_iic_scl <= 1'b0;
                                                        default:
                                                                begin
                                                                        o_iic_scl <= 1'b1;
                                                                        o_iic_sda <= 1'b1;
                                                                end
                                                endcase
                                        end
                        CHECK_SLAVE_ACK: //检测从机应答状态
                                if(scl_plus) //状态分割计数器计满一次，代表状态要进行更新
                                        begin
                                                if(state_counter == 3) //状态记录计数器
                                                        state_counter <= 0;
                                                else
                                                        state_counter <= state_counter + 1;
                                                case (state_counter) //线性序列机完成检测从机应答位时序
                                                        0:
                                                                begin
                                                                        iic_sda_oe <= 1'b0;
                                                                        o_iic_scl <= 1'b0;
                                                                end
                                                        1:
                                                                o_iic_scl <= 1'b1;
                                                        2:
                                                                begin
                                                                        o_iic_scl <= 1'b1;
                                                                        o_ack <= iic_sda; //此时的 SDA 由从机控制，o_ack 采样从机的应答信号并输出，如果从机的应答信号出现问题，用户可以立刻发现
                                                                end
                                                        3:
                                                                o_iic_scl <= 1'b0;
                                                        default:
                                                                begin
                                                                        o_iic_scl <= 1'b1;
                                                                        o_iic_sda <= 1'b1;
                                                                end
                                                endcase
                                                if(state_counter == 3)
                                                        if(!(i_cmd & STO))
                                                                o_iic_done <= 1'b1; //传输完成，拉高标志信号
                                        end
                        MASTER_GENERATE_ACK: //主机产生应答状态
                                if(scl_plus) //状态分割计数器计满一次，代表状态要进行更新
                                        begin
                                                if(state_counter == 3) //状态记录计数器
                                                        state_counter <= 0;
                                                else
                                                        state_counter <= state_counter + 1;
                                                case (state_counter) //线性序列机完成主机产生应答时序
                                                        0:
                                                                begin
                                                                        iic_sda_oe <= 1'b1;
                                                                        o_iic_scl <= 1'b0;
                                                                        if(i_cmd & ACK) //如果包含应答指令，拉低 SDA 信号
                                                                                o_iic_sda <= 1'b0;
                                                                        else if(i_cmd & NACK) //如果包含非应答指令，拉高 SDA 信号
                                                                                o_iic_sda <= 1'b1;
                                                                end
                                                        1:
                                                                o_iic_scl <= 1'b1;
                                                        2:
                                                                begin
                                                                        o_iic_scl <= 1'b1;
                                                                end
                                                        3:
                                                                o_iic_scl <= 1'b0;
                                                        default:
                                                                begin
                                                                        o_iic_scl <= 1'b1;
                                                                        o_iic_sda <= 1'b1;
                                                                end
                                                endcase
                                                if(state_counter == 3)
                                                        if(!(i_cmd & STO))
                                                                o_iic_done <= 1'b1; //传输完成，拉高标志信号
                                        end
                        STOP:   //停止位状态，产生停止位信号
                                if(scl_plus) //状态分割计数器计满一次，代表状态要进行更新
                                        begin
                                                if(state_counter == 3) //状态记录计数器
                                                        state_counter <= 0;
                                                else
                                                        state_counter <= state_counter + 1;
                                                case (state_counter) //线性序列机完成停止位时序
                                                        0:
                                                                begin
                                                                        o_iic_sda <= 1'b0;
                                                                        iic_sda_oe <= 1'b1;
                                                                end
                                                        1:
                                                                o_iic_scl <= 1'b1;
                                                        2:
                                                                begin
                                                                        o_iic_scl <= 1'b1;
                                                                        o_iic_sda <= 1'b1;
                                                                end
                                                        3:
                                                                o_iic_scl <= 1'b1;
                                                        default:
                                                                begin
                                                                        o_iic_scl <= 1'b1;
                                                                        o_iic_sda <= 1'b1;
                                                                end
                                                endcase
                                                if(state_counter == 3)
                                                        o_iic_done <= 1'b1; //传输完成，拉高标志信号
                                        end
                endcase

endmodule
/*
In this project, we just need 2 outports:data_valid and data_pixel.
*/
module dvp_capture
(
        input           pclk            ,
        input           rst_n           ,
        input           vsync           ,
        input           href            ,
        input   [7:0]   data            ,

        output          image_state     ,
        output          data_valid      ,
        output  [15:0]  data_pixel      ,
        output          data_hs         ,
        output          data_vs         ,
        output  [11:0]  xaddr           ,
        output  [11:0]  yaddr
);

// output port
reg             r_image_state           ;
reg             r_data_hs               ;
reg             r_data_vs               ;
reg     [15:0]  r_data_pixel            ;
assign  image_state = r_image_state     ;
assign  data_hs = r_data_hs             ;
assign  data_vs = r_data_vs             ;
assign  data_pixel = r_data_pixel       ;

// reg definitions
reg             r_vsync                 ; // 用于进行边沿检测
reg             r_href                  ; // 用于进行边沿检测
reg     [7:0]   r_data                  ; // 用于进行边沿检测
reg             r_data_valid            ;
reg     [12:0]  h_count                 ;
reg     [11:0]  v_count                 ;
reg     [3:0]   frame_cnt               ; // 帧计数器
reg             dump_frame              ; // dump_frame信号，表示当前帧是否需要丢弃

// data_valid 信号
assign  data_valid = r_data_valid & dump_frame;

// 等到初始化摄像完成后且场同步信号出现，释放清零信号，开始写入数据
always @(posedge pclk or negedge rst_n)
        if (!rst_n)
                r_image_state <= 1'b1;
        else if (r_vsync)
                r_image_state <= 1'b0;

// 对DVP接口的数据使用寄存器打一拍，防止亚稳态，并且可以用于边沿检测
always @(posedge pclk)
        begin
                r_vsync <= vsync;
                r_href <= href;
                r_data <= data;
        end

// 边沿检测
wire    r_vsync_posedge;
assign   r_vsync_posedge = (r_vsync == 1'b0 && vsync == 1'b1); // vsync 信号的上升沿
wire    r_href_posedge;
assign   r_href_posedge = (r_href == 1'b0 && href == 1'b1); // href 信号的上升沿

// 在 href 信号为高电平时，计数输出数据个数，也就是 x 地址
always @(posedge pclk or negedge rst_n)
        if (!rst_n)
                h_count <= 13'd0;
        else if (r_href)
                h_count <= h_count + 1'd1;
        else
                h_count <= 13'd0;

/*
当计数器的计数值为偶数时，将DVP接口数据端上的数据存到输出像素数据的高字节，
当计数器的计数值为奇数时，将DVP接口数据端上的数据存到输出像素数据的低字节。
*/
always @(posedge pclk or negedge rst_n)
        if (!rst_n)
                r_data_pixel <= 16'd0;
        else if (h_count[0])
                r_data_pixel[7:0] <= r_data;
        else
                r_data_pixel[15:8] <= r_data;

// 在行计数器的计数值为奇数时且 href 信号为高电平时，产生输出数据有效信号
always @(posedge pclk or negedge rst_n)
        if (!rst_n)
                r_data_valid <= 1'b0;
        else if (r_href && h_count[0])
                r_data_valid <= 1'b1;
        else
                r_data_valid <= 1'b0;

// 产生行、场同步信号
always @(posedge pclk)
        begin
                r_data_hs <= r_href;
                r_data_vs <= r_vsync;
        end

// 使用 v_count 计数器对 href 信号的高电平进行计数，统计一帧图像中的每一行图像的行号，也就是 y 地址
always @(posedge pclk or negedge rst_n)
        if (!rst_n)
                v_count <= 12'd0;
        else if (r_vsync)
                v_count <= 12'd0;
        else if (r_href_posedge) // href 信号的上升沿
                v_count <= v_count + 1'd1;
        else
                v_count <= v_count;

// 输出 x 地址
assign  xaddr = h_count[12:1]; // 由于一行 N 个像素的图像输出 2N 个数据，所以 h_count 计数值为 N 的 2 倍，将该计数值除以 2 即可得到 x 地址

// 输出 y 地址
assign  yaddr = v_count;

// 帧计数器，对每次系统开始运行后的前 10 帧进行计数
always @(posedge pclk or negedge rst_n)
        if (!rst_n)
                frame_cnt <= 4'd0;
        else if (r_vsync_posedge) // vsync 信号的上升沿
                if (frame_cnt == 4'd10)
                        frame_cnt <= 4'd10;
                else
                        frame_cnt <= frame_cnt + 1'b1;
        else
                frame_cnt <= frame_cnt;

// 舍弃前 10 帧图像数据
always @(posedge pclk or negedge rst_n)
        if (!rst_n)
                dump_frame <= 1'b0;
        else if (frame_cnt >= 4'd10)
                dump_frame <= 1'b1;
        else
                dump_frame <= 1'b0;

endmodule
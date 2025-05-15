module tft_disp
(
        input                   i_clk_9m                , // 9 MHz clock
        input                   i_sysrst_n              , // system reset
        input   [15:0]          i_data_in               , // data input

        output                  read_data_req           , // data request
        output  [15:0]          rgb_data_tft            , // rgb data output
        output                  tft_hsync               , // tft hsync signal
        output                  tft_vsync               , // tft vsync signal
        output                  tft_clk                 , // tft pixel clock
        output                  tft_de                  , // tft data enable
        output                  tft_bl                    // tft backlight control
);

//********************************Parameter************************************//
// hsync
parameter   H_SYNC      = 11'd41        ; // tft hsync pulse width
parameter   H_BACK      = 11'd2         ; // tft hsync back edge
parameter   H_LEFT      = 11'd0         ; // tft hsync left border
parameter   H_VALID     = 11'd480       ; // tft hsync data valid
parameter   H_RIGHT     = 11'd0         ; // tft hsync right border
parameter   H_FRONT     = 11'd2         ; // tft hsync front edge
parameter   H_TOTAL     = 11'd525       ; // tft hsync sweep cycle
// vsync
parameter   V_SYNC      = 11'd10        ; // tft vsync pulse width
parameter   V_BACK      = 11'd2         ; // tft vsync back edge
parameter   V_TOP       = 11'd0         ; // tft vsync left border
parameter   V_VALID     = 11'd272       ; // tft vsync data valid
parameter   V_BOTTOM    = 11'd0         ; // tft vsync right border
parameter   V_FRONT     = 11'd2         ; // tft vsync front edge
parameter   V_TOTAL     = 11'd286       ; // tft vsync sweep cycle

//********************************Internal Wire and Reg define**************************//
// wire define
wire            data_valid           ; // data valid area
//reg   define
reg     [9:0]   cnt_h                ; // hsync counter
reg     [9:0]   cnt_v                ; // vsync counter

//*****************************Main Code************************************//
// tft_clk, tft_de, tft_bl
assign  tft_clk     = i_clk_9m;
assign  tft_de      = data_valid;
assign  tft_bl      = i_sysrst_n;

// cnt_h
always@(posedge i_clk_9m or negedge i_sysrst_n)
        if(!i_sysrst_n)
                cnt_h   <=  10'd0;
        else    if(cnt_h == H_TOTAL)
                cnt_h   <=  10'd0;
        else
                cnt_h   <=  cnt_h + 10'd1;

// cnt_v
always@(posedge i_clk_9m or negedge i_sysrst_n)
        if(!i_sysrst_n)
                cnt_v   <=  10'd0;
        else    if(cnt_h == H_TOTAL)
                if(cnt_v == V_TOTAL)
                        cnt_v   <=  10'd0;
                else
                        cnt_v   <=  cnt_v + 10'd1;
        else 
                cnt_v   <=  cnt_v;

// data_valid:valid display area
assign  data_valid = ((cnt_h >= (H_SYNC + H_BACK + H_LEFT)) && (cnt_h < (H_SYNC + H_BACK + H_LEFT + H_VALID))) && ((cnt_v >= (V_SYNC + V_BACK + V_TOP)) && (cnt_v < (V_SYNC + V_BACK + V_TOP + V_VALID)));
//data_req:data request, this signal is a handshake signal with sdram_top. When this signal is high, it means that we need to read data from sdram. Note that this signal must be more than 1 clock cycle than the data_valid signal to ensure the timing is correct.
assign  read_data_req = ((cnt_h >= (H_SYNC + H_BACK + H_LEFT - 1'b1)) && (cnt_h < (H_SYNC + H_BACK + H_LEFT + H_VALID - 1'b1))) && ((cnt_v >= (V_SYNC + V_BACK + V_TOP)) && (cnt_v < (V_SYNC + V_BACK + V_TOP + V_VALID)));

// tft_hsync,tft_vsync,rgb_data_tft
// use other tft timing:using tft_de signal control tft display, so tft_hsync and tft_vsync are always high
assign  hsync   = 1'b1;
assign  vsync   = 1'b1;
assign  rgb_tft = (data_valid == 1'b1) ? i_data_in : 16'h0000;

endmodule
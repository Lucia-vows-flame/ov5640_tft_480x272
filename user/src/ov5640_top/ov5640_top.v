module ov5640_top
(
        input                   i_sysclk                , // system clock
        input                   i_pclk                  , // pixel clock
        input                   i_sysrst_n              , // system reset
        input                   i_vsync                 , // vsync signal
        input                   i_href                  , // href signal
        input   [7:0]           i_data                  , // ov5640 input data
        input                   i_sys_init_done         , // system init done signal. when camera init done and other modules init done, this signal will be high
        output                  data_valid              , // data valid signal
        output  [15:0]          rgb_data                , // rgb data output
        output                  camera_init_done        , // camera init done signal
        output                  camera_rst_n            , // camera reset signal
        output                  camera_pwdn             , // camera power down signal
        output                  iic_sclk                , // iic clock signal
        inout                   iic_sdat                  // iic data signal
);

wire	dvp_rst_n;	// dvp reset signal

//********************************Instantion************************************//
// camera_init
camera_init #(
	.CAMERA_TYPE     	( "ov5640"  ),
	.IMAGE_TYPE      	( 0         ),
	.IMAGE_WIDTH     	( 480       ),
	.IMAGE_HEIGHT    	( 272       ),
	.IMAGE_FLIP_EN   	( 0         ),
	.IMAGE_MIRROR_EN 	( 0         ))
u_camera_init(
	.i_sysclk     	( i_sysclk              ),
	.i_sysrst_n   	( i_sysrst_n            ),
	.init_done    	( camera_init_done      ),
	.camera_rst_n 	( camera_rst_n          ),
	.camera_pwdn  	( camera_pwdn           ),
	.iic_sclk     	( iic_sclk              ),
	.iic_sdat     	( iic_sdat              )
);

// dvp_capture
// dvp_rst_n
assign dvp_rst_n = i_sys_init_done & camera_init_done;
dvp_capture u_dvp_capture(
	.pclk        	( i_pclk       ),
	.rst_n       	( dvp_rst_n    ),
	.vsync       	( i_vsync      ),
	.href        	( i_href       ),
	.data        	( i_data       ),
	.image_state 	(              ),
	.data_valid  	( data_valid   ),
	.data_pixel  	( rgb_data     ),
	.data_hs     	(              ),
	.data_vs     	(              ),
	.xaddr       	(              ),
	.yaddr       	(              )
);

endmodule
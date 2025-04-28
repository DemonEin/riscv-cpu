// sharing these between implementation and tests fails to cover testing their
// values, but duplicating these wouldn't have much value

`ifndef INCLUDE_USB_CONSTANTS
`define INCLUDE_USB_CONSTANTS

localparam BREQUEST_GET_STATUS = 0;
localparam BREQUEST_CLEAR_FEATURE = 1;
localparam BREQUEST_SET_FEATURE = 3;
localparam BREQUEST_SET_ADDRESS = 5;
localparam BREQUEST_GET_DESCRIPTOR = 6;
localparam BREQUEST_SET_DESCRIPTOR = 7;
localparam BREQUEST_GET_CONFIGURATION = 8;
localparam BREQUEST_SET_CONFIGURATION = 9;
localparam BREQUEST_GET_INTERFACE = 10;
localparam BREQUEST_SET_INTERFACE = 11;
localparam BREQUEST_SYNCH_FRAME = 12;

localparam DESCRIPTOR_TYPE_DEVICE = 1;
localparam DESCRIPTOR_TYPE_CONFIGURATION = 2;
localparam DESCRIPTOR_TYPE_STRING = 3;
localparam DESCRIPTOR_TYPE_INTERFACE = 4;
localparam DESCRIPTOR_TYPE_ENDPOINT = 5;

localparam PID_OUT = 4'b0001;
localparam PID_IN = 4'b1001;
localparam PID_SETUP = 4'b1101;
localparam PID_DATA0 = 4'b0011;
localparam PID_DATA1 = 4'b1011;
localparam PID_ACK = 4'b0010;
localparam PID_NAK = 4'b1010;
localparam PID_STALL = 4'b1110;
localparam PID_NYET = 4'b0110;

`endif

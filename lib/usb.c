#include "cpulib.h"

#define BREQUEST_GET_STATUS 0
#define BREQUEST_CLEAR_FEATURE 1
#define BREQUEST_SET_FEATURE 3
#define BREQUEST_SET_ADDRESS 5
#define BREQUEST_GET_DESCRIPTOR 6
#define BREQUEST_SET_DESCRIPTOR 7
#define BREQUEST_GET_CONFIGURATION 8
#define BREQUEST_SET_CONFIGURATION 9
#define BREQUEST_GET_INTERFACE 10
#define BREQUEST_SET_INTERFACE 11
#define BREQUEST_SYNCH_FRAME 12

#define DESCRIPTOR_TYPE_DEVICE 1
#define DESCRIPTOR_TYPE_CONFIGURATION 2
#define DESCRIPTOR_TYPE_STRING 3
#define DESCRIPTOR_TYPE_INTERFACE 4
#define DESCRIPTOR_TYPE_ENDPOINT 5
#define DESCRIPTOR_TYPE_DEVICE_QUALIFIER 6

#define USB_CONTROL_IGNORE (1 << 23)

struct setup_data {
    uint8_t bmRequestType;
    uint8_t bRequest;
    uint16_t wValue;
    uint16_t wIndex;
    uint16_t wLength;
};

struct bConfiguration {
    uint8_t bLength;
    uint8_t bDescriptorType;
    uint16_t wTotalLength;
    uint8_t bNumInterfaces;
    uint8_t bConfigurationValue;
    uint8_t iConfiguration;
    uint8_t bmAttributes;
    uint8_t bMaxPower;
};

extern volatile char usb_data_buffer[1024];

/* bits 0-9: length of data in bytes
 * bits 10-16: address
 * bits 17-20: endpoint
 * bits 21-22: when receiving an interrupt:
 *                 00 for OUT
 *                 10 for IN
 *                 11 for SETUP
 *
 *             when writing the handshake to send:
 *                 00 for ACK
 *                 10 for NAK
 *                 11 for STALL
 *
 *             (the top two bits of the PID)
 * bit 23: when writing, 1 to ignore the transaction
 *         and 0 to respond (either with handshake or data)
 *             
 * writing to this signals to the gateware to continue
 */
extern volatile uint32_t usb_control;

static bool in_control_transfer = false;
static uint8_t device_address = 0;
static struct bConfiguration configuration = {
    sizeof(configuration),
    DESCRIPTOR_TYPE_CONFIGURATION,
    sizeof(configuration),
    1,
    0,
    0,
    0b10000000,
    0 // TODO come up with a real number for this
};

/* an usb external interrupt is triggered when receiving the data packet of an OUT transaction
 * and the token packet of an IN transaction
 *
 * in both, usb_control contains the address, endpoint, and token type
 *
 * in an OUT transaction:
 *     usb_control contains the length of the data section
 *     usb_data_buffer contains the data
 *     any write to usb_control clears the interrupt, signals to
 *         the gateware it now owns the data buffer, and causes the gateware
 *         to send a handshake of the type specified by usb_control
 *
 * in an IN transaction:
 *     any write to usb_control clears the interrupt and causes the
 *         gateware to send the numbers of bytes specified by usb_control
 *        in usb_data_buffer in a data packet
 */
static uint32_t make_usb_response(const uint32_t usb_control_copy) {
    if (((usb_control_copy >> 10) & 0x7f) != device_address) {
        return USB_CONTROL_IGNORE;
    }

    switch ((usb_control_copy >> 21) & 0b11) {
        case 0b11: // setup
            struct setup_data* setup_data = (struct setup_data*) usb_data_buffer;
            switch (setup_data->bRequest) {
                case BREQUEST_SET_ADDRESS:
                    device_address = setup_data->wValue;
                    simulation_print("got set address packet");
                    return 0;
                case BREQUEST_GET_CONFIGURATION:
                    if (device_address == 0) { // device is in address state
                        usb_data_buffer[0] = 0;
                        return 1;
                    } else {
                        // device is in configured state
                        *(struct bConfiguration*) usb_data_buffer = configuration;
                        return sizeof(configuration);
                    }
                /*
                case BREQUEST_GET_INTERFACE: // device to host (read) transaction
                                             // send request error by sending stall
                                             // so I need a way to control whether the
                                             // usb module should respond with STALL or ACK
                                             // in the handshake of an out transaction
                    // always send request error
                */
            }
            break;
        case 0b00: // out
            return USB_CONTROL_IGNORE;
            break;
        case 0b10: // in
            return USB_CONTROL_IGNORE;
            break;
        default:
            simulation_print("invalid token bits");
            return USB_CONTROL_IGNORE;
    }

    simulation_print("did not return earlier");
    return USB_CONTROL_IGNORE;
}

void handle_usb_transaction() {
    usb_control = make_usb_response(usb_control);
}

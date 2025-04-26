#include "cpulib.h"
#include <assert.h>
#include <stdio.h>

enum bRequest : uint8_t {
    BREQUEST_GET_STATUS = 0,
    BREQUEST_CLEAR_FEATURE = 1,
    BREQUEST_SET_FEATURE = 3,
    BREQUEST_SET_ADDRESS = 5,
    BREQUEST_GET_DESCRIPTOR = 6,
    BREQUEST_SET_DESCRIPTOR = 7,
    BREQUEST_GET_CONFIGURATION = 8,
    BREQUEST_SET_CONFIGURATION = 9,
    BREQUEST_GET_INTERFACE = 10,
    BREQUEST_SET_INTERFACE = 11,
    BREQUEST_SYNCH_FRAME = 12,
};

enum bDescriptorType : uint8_t {
    DESCRIPTOR_TYPE_DEVICE = 1,
    DESCRIPTOR_TYPE_CONFIGURATION = 2,
    DESCRIPTOR_TYPE_STRING = 3,
    DESCRIPTOR_TYPE_INTERFACE = 4,
    DESCRIPTOR_TYPE_ENDPOINT = 5,
    DESCRIPTOR_TYPE_DEVICE_QUALIFIER = 6,
};

struct setup_data {
    uint8_t bmRequestType;
    enum bRequest bRequest;
    uint16_t wValue;
    uint16_t wIndex;
    uint16_t wLength;
};

struct bConfiguration {
    uint8_t bLength;
    enum bDescriptorType bDescriptorType;
    uint16_t wTotalLength;
    uint8_t bNumInterfaces;
    uint8_t bConfigurationValue;
    uint8_t iConfiguration;
    uint8_t bmAttributes;
    uint8_t bMaxPower;
};

enum token {
    TOKEN_OUT = 0b00,
    TOKEN_IN = 0b10,
    TOKEN_SETUP = 0b11,
};

enum handshake {
    HANDSHAKE_ACK = 0b00,
    HANDSHAKE_NAK = 0b10,
    HANDSHAKE_STALL = 0b11,
};

extern volatile uint8_t usb_data_buffer[1023];

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
 * bits 23-24: when writing:
 *     00 to ignore the transaction
 *     01 to respond with a handshake packet
 *     10 to respond with a data packet
 *             
 * writing to this signals to the gateware to continue
 */
extern volatile uint32_t usb_control;
static bool in_control_transfer;
static struct setup_data setup_data;

static uint8_t device_address = 0;
static uint8_t bConfigurationValue = 0;
static struct bConfiguration configuration = {
    sizeof(configuration),
    DESCRIPTOR_TYPE_CONFIGURATION,
    sizeof(configuration),
    1,
    1,
    0,
    0b10000000,
    0 // TODO come up with a real number for this
};

struct response {
    enum response_type {
        RESPONSE_TYPE_IGNORE = 0b00,
        RESPONSE_TYPE_HANDSHAKE = 0b01,
        RESPONSE_TYPE_DATA = 0b10,
    } type;
    union {
        enum handshake handshake;
        uint16_t data_length;
    };
};
#define RESPONSE_IGNORE ((struct response){ RESPONSE_TYPE_IGNORE, 0 })
#define RESPONSE_ACK ((struct response){ RESPONSE_TYPE_HANDSHAKE, HANDSHAKE_ACK })
#define RESPONSE_NAK ((struct response){ RESPONSE_TYPE_HANDSHAKE, HANDSHAKE_NAK })
#define RESPONSE_STALL ((struct response){ RESPONSE_TYPE_HANDSHAKE, HANDSHAKE_STALL })
#define RESPONSE_DATA(LENGTH) ((struct response){ RESPONSE_TYPE_DATA, LENGTH })

static struct response handle_setup_transaction(uint16_t data_length) {
    if (data_length != 8) {
        puts("got bad number of bytes for setup transaction");
        return (struct response){ RESPONSE_TYPE_IGNORE, 0 };
    }

    in_control_transfer = true;
    setup_data = *(volatile struct setup_data*)usb_data_buffer;
    return (struct response){ RESPONSE_TYPE_HANDSHAKE, HANDSHAKE_ACK };
}

static struct response handle_out_transaction(uint16_t data_length) {
    if (!in_control_transfer) {
        return (struct response){ RESPONSE_TYPE_HANDSHAKE, HANDSHAKE_NAK };
    }

    if ((setup_data.bmRequestType & (1 << 7)) == 0x80) {
        // in the status stage of an IN control transfer
        in_control_transfer = false;
        return (struct response){ RESPONSE_TYPE_HANDSHAKE, HANDSHAKE_ACK };
    } else {
        // in the data stage of an OUT control transfer
    }
    return (struct response){ RESPONSE_TYPE_IGNORE, 0 };
}

static struct response handle_in_transaction() {
    if (!in_control_transfer) {
        // TODO return some kind of bad handshake in the error case
        return (struct response){ RESPONSE_TYPE_IGNORE, 0 };
    }

    if ((setup_data.bmRequestType & (1 << 7)) == 0x80) { // 0 is host-to-device, 1 is device-to-host
        // this is a data stage of an in control transfer
        switch (setup_data.bRequest) {
            case BREQUEST_GET_CONFIGURATION:
                usb_data_buffer[0] = bConfigurationValue;
                return (struct response){ RESPONSE_TYPE_DATA, 1 };
            default:
                // TODO return some kind of bad handshake
                return (struct response){ RESPONSE_TYPE_HANDSHAKE, HANDSHAKE_STALL };
        }
    } else {
        // this is the status stage of an out control transfer

        struct response response;
        switch (setup_data.bRequest) {
            case BREQUEST_SET_ADDRESS:
                // has to be done in the setup stage, unlike other transfers
                device_address = setup_data.wValue;
                response = RESPONSE_DATA(0);
                break;
            case BREQUEST_SET_CONFIGURATION:
                if (setup_data.wValue <= 1) {
                    bConfigurationValue = setup_data.wValue;
                    response = RESPONSE_DATA(0);
                } else {
                    response = RESPONSE_STALL;
                }
                break;
            case BREQUEST_CLEAR_FEATURE:
                response = RESPONSE_STALL;
                break;
            case BREQUEST_SET_DESCRIPTOR:
                response = RESPONSE_STALL;
                break;
            case BREQUEST_SET_FEATURE:
                response = RESPONSE_STALL;
                break;
            case BREQUEST_SET_INTERFACE:
                response = RESPONSE_STALL;
                break;
            default:
                response = RESPONSE_STALL;
                break;
        }

        in_control_transfer = false;
        return response;
    }
}

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
static struct response make_usb_response(const uint32_t usb_control_copy) {
    if (((usb_control_copy >> 10) & 0x7f) != device_address) {
        puts("ignoring due to address");
        return (struct response){ RESPONSE_TYPE_IGNORE, 0 };
    }

    const unsigned int token = usb_control_copy >> 21 & 0b11;
    if (token == TOKEN_SETUP || token == TOKEN_OUT) {
        const uint16_t data_length = usb_control_copy & 0x3ff;
        return token == TOKEN_SETUP ? handle_setup_transaction(data_length)
                                    : handle_out_transaction(data_length);
    } else if (token == TOKEN_IN) {
        return handle_in_transaction();
    } else {
        puts("invalid token bits");
        return (struct response){ RESPONSE_TYPE_IGNORE, 0 };
    }
}

void handle_usb_transaction() {
    const struct response response = make_usb_response(usb_control);
    uint32_t result_usb_control = response.type << 23;
    switch (response.type) {
        case RESPONSE_TYPE_IGNORE:
            break;
        case RESPONSE_TYPE_HANDSHAKE:
            result_usb_control |= response.handshake << 21;
            break;
        case RESPONSE_TYPE_DATA:
            result_usb_control |= response.data_length & 0x3ff;
            break;
        default:
            assert(false);
    }

    usb_control = result_usb_control;
}

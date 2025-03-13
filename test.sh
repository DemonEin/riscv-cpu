#!/bin/bash

make -C tests/cpu sim && make -C tests/usb test

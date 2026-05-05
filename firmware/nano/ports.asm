;==================================== NIO ============================================
NIO_A_DATA          .EQU  010h
NIO_A_DIR           .EQU  012h

NIO_B_DATA          .EQU  011h
NIO_B_CTRL          .EQU  013h

NIO_TEST_BITS       .EQU  04Fh      ; Note - MicroBeast PIO interprets this as mode 1, all inputs
NIO_VALID_LOWER     .EQU  0D4h      ; Bit pattern returned by LCD translation..
NIO_VALID_UPPER     .EQU  0FAh

NIO_I2C_IDLE        .EQU  081h

NI2C_DATA_BIT       .EQU    7           ; I2C on Port B CTRL
NI2C_CLK_BIT        .EQU    0

NI2C_DATA_MASK      .EQU    1 << NI2C_DATA_BIT
NI2C_CLK_MASK       .EQU    1 << NI2C_CLK_BIT

NI2C_REGISTER       .EQU    00h

NAUDIO_PORT         .EQU    NIO_B_CTRL
NAUDIO_REGISTER     .EQU    04h         ; Audio on Port B CTRL
NAUDIO_MASK         .EQU    01h

NINT_REGISTER       .EQU    02h         ; INT register controls interrupt inputs
EXT_INT_MASK        .EQU    08h
UART_INT_MASK       .EQU    10h
RTC_INT_MASK        .EQU    20h
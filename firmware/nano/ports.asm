;==================================== NIO ============================================
NIO_A_DATA          .EQU  010h
NIO_A_DIR           .EQU  011h

NIO_TEST_BITS       .EQU  04Fh      ; Note - MicroBeast PIO interprets this as mode 1, all inputs
NIO_VALID_LOWER     .EQU  0D4h      ; Bit pattern returned by LCD translation..
NIO_VALID_UPPER     .EQU  0FAh

NIO_B_DATA          .EQU  014h      ; Port B inputs

NIO_AUDIO_PORT      .EQU  015h      ; Audio output port

NAUDIO_MASK         .EQU   01h

NIO_INT_PORT        .EQU  016h      ; Interrupt mask port

EXT_INT_MASK        .EQU   08h
UART_INT_MASK       .EQU   10h
RTC_INT_MASK        .EQU   20h

NIO_I2C_PORT        .EQU  017h      ; I2C port

NI2C_DATA_BIT       .EQU    7       
NI2C_CLK_BIT        .EQU    0

NI2C_DATA_MASK      .EQU    1 << NI2C_DATA_BIT
NI2C_CLK_MASK       .EQU    1 << NI2C_CLK_BIT

NIO_I2C_IDLE        .EQU  NI2C_DATA_MASK | NI2C_CLK_MASK




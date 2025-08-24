.include "./m328Pdef.inc"

.org 0x0000

;--------------------------
; I/O AYARLARI
;--------------------------
    ldi r16, 0b11111100        ; PD2–PD7 çıkış
    out DDRD, r16
    ldi r16, 0b00000011        ; PB0–PB1 çıkış
    out DDRB, r16

;--------------------------
; ADC AYARLARI (ADC2, AVcc, sol hizalı)
; ADCH hız için kullanılacak
;--------------------------
    ldi r16, 0b01100010        ; REFS0=1 (AVcc), ADLAR=1, MUX=0010 (ADC2)
    sts ADMUX, r16
    ldi r16, 0b10000111        ; ADEN=1, prescaler=128
    sts ADCSRA, r16

;--------------------------
; DEĞİŞKENLER
; r20: LED maskesi (tek 1 bit)
; r21: yön (0=sola doğru LSL, 1=sağa doğru LSR)
; r18: gecikme için ADCH kopyası
;--------------------------
    ldi r20, 0b00000001        ; başlangıç: en sağ (bit0)
    ldi r21, 0                 ; yön: 0 = sola (LSL)

main_loop:

;--- ADC başlat
    lds r16, ADCSRA
    ori r16, (1<<ADSC)
    sts ADCSRA, r16

;--- ADC bitene kadar bekle
adc_wait:
    lds r16, ADCSRA
    sbrc r16, ADSC
    rjmp adc_wait

;--- Hız için ADCH oku
    lds r17, ADCH
    mov r18, r17

;--------------------------
; KNIGHT RIDER MANTIĞI
; Uçlara gelince yön değiştir
;--------------------------
    cpi r21, 0
    brne dir_right

;--- Yön: SOL (LSL). Uçta mıyız? (0x80)
    cpi r20, 0x80
    brne do_lsl
    ldi r21, 1                 ; artık sağa (LSR)
    rjmp do_lsr

do_lsl:
    lsl r20
    rjmp write_leds

dir_right:
;--- Yön: SAĞ (LSR). Uçta mıyız? (0x01)
    cpi r20, 0x01
    brne do_lsr
    ldi r21, 0                 ; artık sola (LSL)
    rjmp do_lsl

do_lsr:
    lsr r20

;--------------------------
; LED ÇIKIŞLARINI YAZ
; PD2–PD7 <= maskenin bit2–bit7'si (2 sola kaydır)
; PB0–PB1 <= maskenin bit6–bit7'si (6 sağa kaydır)
;--------------------------
write_leds:
    mov r22, r20
    lsl r22
    lsl r22
    andi r22, 0b11111100       ; yalnız PD2–PD7'i değiştir
    out PORTD, r22

    mov r24, r20
    lsr r24
    lsr r24
    lsr r24
    lsr r24
    lsr r24
    lsr r24
    andi r24, 0b00000011       ; yalnız PB0–PB1'i değiştir
    out PORTB, r24

;--------------------------
; GECİKME (ADCH ile ölçeklenir)
;--------------------------
    rcall delay_adc
    rjmp main_loop

;--------------------------
; Delay alt programı
; r18: ADCH (0..255)
; Daha yüksek ADCH -> daha kısa gecikme için tersliyoruz.
;--------------------------
delay_adc:
    mov r23, r18
    ldi r27, 0xFF
    sub r27, r23               ; r27 = 255 - ADCH

delay_outer:
    ldi r25, 0x9C
    ldi r24, 0x3E
delay_loop:
    sbiw r24, 1
    brne delay_loop
    nop
    dec r27
    brne delay_outer
    ret

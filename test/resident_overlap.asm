; Test payload spanning all five BASIC 4.0 resident helper services.
; At $97F0, nine 254-byte directory blocks conservatively reach beyond
; $9FFF, so the overlap dialog must name every service.
        * = ADDR
        rts
        .fill 2100, 0

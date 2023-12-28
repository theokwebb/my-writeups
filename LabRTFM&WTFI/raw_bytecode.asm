PUBLIC asm_scratchpad

.code
asm_scratchpad PROC 
   db 0B8h
   dd 0AABBCCDDh
   db 09Eh
   db 074h
   db 05h
   db 025h
   dd 031337h
   mylabel:
   db 0C3h
asm_scratchpad ENDP
end

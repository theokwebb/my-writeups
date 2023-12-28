# OpenSecurityTraining2 Arch1001: Lab RTFM & WTFI!

## Challenge Description
In this challenge we were asked to write raw bytecode to create the following assembly sequence:
```asm
mov eax, 0xAABBCCDD
sahf
jz mylabel
and eax, 0x31337
mylabel:
ret
```
## Read the F*n Intel Manual
In the Intel® 64 and IA-32 Architectures Software Developer’s Manual[^1], the object code (opcode) produced for each instructions can be found, which the processor interprets as instructions. I.e., the human-readable representation of `RET` is opcode `C3`. 

## `mov eax, 0xAABBCCDD`
So, first to write the raw bytecode of `mov eax, 0xAABBCCDD`.
Under `MOV` in Intel manual (Page 1211), there are numerous opcodes, but there is one which matches `mov eax, 0xAABBCCDD`; `B8+ rd id`. Why? `EAX` is one of the doubleword general-purpose registers and is represented by the symbol `r32` in instruction statements. `0xAABBCCDD` is a constant value which is specified directly in the instruction itself (as opposed to being stored in a separate location in memory) and referred to as an immediate operand (`imm`). Therefore, we need the instruction which moves an immediate of 4+ bytes (`0xAABBCCDD`) into an `r32`. This is evidently `MOV r32, imm32`, or `B8+ rd id` in opcode:

![MOV](https://github.com/theokwebb/my-writeups/blob/main/LabRTFM%26WTFI/MOV.png)

To write this in hexadecimal opcode you use `db` (define byte) and `dd` (define dword) directives to declare the values:
```asm
db 0B8h
dd 0AABBCCDDh
```
`dd` is used because `0AABBCCDDh` is a 32-bit/4 byte value and not a byte (`db`). `MASM` also doesn't like immediates or raw bytes that start with an alphabet character, so the values must be preceded by a zero.

## `SAHF`
So, according to the Intel manual (Page 1764), the SAHF instruction “loads SF, ZF, AF, PF, and CF from AH into EFLAGS register.” and is represented by `9E` in opcode. Therefore, we can simply write:
```asm
db 09Eh
```
`0xAABBCCDD` was moved into `EAX`, so `AH` is `0xCC` (BIN = 1100 1100). `AH`’s bit values (11001100) are loaded into the EFLAGS register. Therefore, as per the EFLAGS register below, `PF` (Parity), `ZF` (Zero) and `SF` (Sign) are set: 

![EFLAGS](https://github.com/theokwebb/my-writeups/blob/main/LabRTFM%26WTFI/EFLAGS.png)

I.e., bit 2 of 11001100 is 1, so its Parity Flag is set.

You can confirm this by looking at the Disassembly after the `SAHF` instruction executes:
```asm
OV = 0 UP = 0 EI = 1 PL = 1 ZR = 1 AC = 0 PE = 1 CY = 0
```
PL = Sign Flag. ZR = Zero Flag. PE = Parity Flag. 

## `jz mylabel`
`jz mylabel` needs to be converted to opcode. However, since we haven’t written the `AND` instruction, we don’t know how far it would need to jump to `mylabel`. Therefore, let’s write the `AND` instruction first so it’s easier to calculate.   

## `and eax, 0x31337`
So, much like `MOV`, we need an `r32` for `EAX` and immediate of at least 3 bytes. Such instruction can be found on page 655 in the manual. `AND EAX, imm32` matches this, and its opcode is `25`. So, we can write:
```asm
db 025h
dd 031337h
mylabel:
```
So, we also write `mylabel:` which serves as a reference point for the jump instruction. As per the Intel manual, such labels are always followed by a colon.

## `jz mylabel`
Now we have the opcode for `AND`, we can easily calculate how many bytes it needs to jump to `mylabel`; one byte for `db`, and four bytes for `dd`, so a total of 5 bytes. Now, to search the manual for a `JZ` which jumps 5 bytes.

There are several `JZ`’s, but only one which matches our target 1-byte range; `JZ rel8` (Page 1107):

![JZ](https://github.com/theokwebb/my-writeups/blob/main/LabRTFM%26WTFI/JZ.png)

`rel8` (relative offset) is a signed 8-bit immediate value which is added to the address of the `RIP` register if `ZF = 1`. This is so it can calculate the target jump address.

So, basically, if the `ZF` is 1, it adds a 1-byte value (provided by us) to the next instruction address (the `RIP` instruction pointer), so it can jump to the `mylabel` address.

So, before the `AND` opcode we write:
```asm
db 074h
db 05h
```
`74` for the `JZ rel8` instruction and `db 05h` for the bytes to jump past the `AND` instruction.

In our case, `ZF` is set by `SAHF`, so it will jump.

## `ret`
Lastly, `RET` (Page 1731) is simply replaced by its opcode `C3` to complete the assembly sequence:
```asm
db 0B8h
dd 0AABBCCDDh
db 09Eh
db 074h
db 05h
db 025h
dd 031337h
mylabel:
db 0C3h
```
Thank you to Xeno at [OpenSecurityTraining2](https://ost2.fyi) for this enjoyable lab and incredible course.

### References:
[^1]: https://ost2images.s3.amazonaws.com/Arch2001/CourseMaterials/325462-sdm-vol-1-2abcd-3abcd.pdf

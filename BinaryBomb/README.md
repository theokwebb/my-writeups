# OpenSecurityTraining2 Arch1001: Binary Bomb Lab

This writeup delves into the Binary Bomb lab, originally designed for [CMU’s architecture class](http://csapp.cs.cmu.edu/3e/labs.html) by Bryant & O'Hallaron and adapted for Intel x86-64 architecture by Xeno Kovah as a part of Xeno’s [Architecture 1001: x86-64 Assembly](https://ost2.fyi/Arch1001) course at [OpenSecurityTraining2](https://ost2.fyi).

The primary objective is to determine the program's required input to prevent the bomb from exploding. 

# Sections
- [Phase 1](#phase-1)
- [Phase 2](#phase-2)
- [Phase 3](#phase-3)
- [Phase 4](#phase-4)
- [Phase 5](#phase-5)
- [Phase 6](#phase-6)
- [Secret Phase](#secretphase)

# Phase 1
<a name="phase-1"></a>
I used WinDBG for this challenge and opted for normal mode, so I was provided with the symbol information in the `bomb.pdb` file. 

I set a breakpoint on `main` and stepped through the instructions. Eventually, we are prompted to enter some input. I entered `test`, as any old input will do for now just to understand how the program functions. 

You can see a call is made to `phase_1`, so I stepped into the function. If we unassemble this function with the WinDBG command `uf phase_1`, there are two instructions that stand out:
```asm
call    bomb!ILT+810(strings_not_equal) (00007ff7`fb95132f)

```
and,
```asm
call    bomb!ILT+945(explode_bomb) (00007ff7`fb9513b6)
```
I assumed that `strings_not_equal` is like the `strcmp` function, comparing our input to another string. If the strings aren't equal, it bypasses the jump and calls `explode_bomb`- an outcome we likely wish to avoid. Therefore, we need to uncover the content at the address where the string is compared.

If we step up to the call of `strings_not_equal`, we can check the arguments provided to the function. In Microsoft x64’s calling convention, argument 1 is held in the `RCX` register, and argument 2 in the `RDX` register. In WinDBG we can display the `ASCII` string at those addresses with: `da <address>`. For example:

![Screenshot1](https://github.com/theokwebb/my-writeups/blob/main/BinaryBomb/Images/Screenshot1.png)
![Screenshot2](https://github.com/theokwebb/my-writeups/blob/main/BinaryBomb/Images/Screenshot2.png)

`strings_not_equal` compares our input to `“I am just a renegade hocky mom.”` As our input is not equal, let’s see what happens if `explode_bomb` is called:

![Screenshot3](https://github.com/theokwebb/my-writeups/blob/main/BinaryBomb/Images/Screenshot3.png)

Therefore, we need to input `“I am just a renegade hockey mom.”` to pass `phase_1` (copy directly from WinDBG to avoid any issues):

![Screenshot4](https://github.com/theokwebb/my-writeups/blob/main/BinaryBomb/Images/Screenshot4.png)

# Phase 2
<a name="phase-2"></a>
If we enter `phase_2` with an arbitrary input of `123` and step through the instructions, it terminates the process from within the function `read_six_numbers`. Therefore, we need to step into this function to find out why.

I thought it would be most efficient to find the exit condition and then work backwards from there. Before the call to `explode_bomb`, there’s a `JGE` which must be taken to bypass `explode_bomb`. For an input of `123`, the first operand in the `CMP` (`rbp+4`) is `0x1`, and the second operand is the immediate `0x6`. Since `0x1` minus `0x6` does not result in a jump, we need to find a way to increase the value at `0x1`.

`CMP`’s operands are `rbp+4` (moved from `EAX`) and the immediate `0x6`. `EAX` stores function return values, and since there was a call to `sscanf` before the `MOV` instruction, `EAX`’s value is derived from `sscanf`. Therefore, we need to understand the `sscanf` function and attempt to increase its return value.
```asm
call    bomb!ILT+705(sscanf) (00007ff7`fb9512c6)
mov     dword ptr [rbp+4],eax
cmp     dword ptr [rbp+4],6
jge     bomb!read_six_numbers+0xae (00007ff7`fb95306e)
```
As stated in [sscanf](https://learn.microsoft.com/en-us/cpp/c-runtime-library/reference/sscanf-sscanf-l-swscanf-swscanf-l?view=msvc-170)’s documentation, `sscanf` reads data from its first argument (a buffer) into the location specified from the third argument, and its second argument is what controls the format of the data. 

In WinDBG we can confirm this in the call to sscanf:

-	RXC (arg1): 7ff7fb960250
-	RDX (arg2): 7ff7fb95c460

![Screenshot5](https://github.com/theokwebb/my-writeups/blob/main/BinaryBomb/Images/Screenshot5.png)

`sscanf`’s return value is determined by the “number of fields successfully converted and assigned”. So, for our input of `123` that was successfully converted, we received a return value of `1`. Therefore, if we follow the format specification of say:

`9 9 9 9 9 9`

It should return `6`. Then, after `CMP`’s second operand `0x6` is subtracted, a jump will occur as `EAX` is now equal to `6`.

![Screenshot6](https://github.com/theokwebb/my-writeups/blob/main/BinaryBomb/Images/Screenshot6.png)

Now, we are back to the `phase_2`. If you read through the next instructions, you will see there are two more potential `explode_bomb` triggers until `ret`.

Before the first call to `explode_bomb`, there’s a `JE` that must be taken. `CMP` subtracts the immediate `0x1` from `rbp+rax+28h`’s value. `rbp+rax+28h`’s value is `0x9` (found with the command `db rbp+rax+28h L1`). Specifically, this is 1st number we provided and can be observed in the memory window:

![Screenshot7](https://github.com/theokwebb/my-writeups/blob/main/BinaryBomb/Images/Screenshot7.png)

`RAX`’s value is `0`, so it uses `RBP` (`ac80f6f680`) + `28h` to access this value. 

`0x9` minus `0x1` does not yield a result of zero, so the Zero Flag is not set and the jump is not taken. However, if we simply change our input to `1 1 1 1 1 1`, it will work:

![Screenshot8](https://github.com/theokwebb/my-writeups/blob/main/BinaryBomb/Images/Screenshot8.png)

If we proceed to step over the next instructions, you will notice a `CMP` and `JGE`, but no subsequent call to `explode_bomb`. In the instructions before this, `0x1` was added to `rbp+4`, and in the subsequent `CMP`, `0x6` is subtracted from `0x1` to determine the outcome of `JGE`. Since these numbers are immediate values, we cannot control this jump, so we have to skip the jump.

If we work backwards from the next call to `explode_bomb`, we can see a `CMP` and `JE`, along with several other important points:

Our first number (`1`) is moved into `ECX` in:
```asm
mov     ecx,dword ptr [rbp+rcx*4+28h]
```

In the pointer arithmetic, where `RCX`’s value is `0`, it accesses our first number (`1`). Then, a `SHL` (Shift Logical Left) operation shifts it by `1` bit, resulting in the number `2`.

Finally, the `CMP` subtracts `ECX` (now a value of `2`) from `rbp+rax*4+28h`’s value. `RAX`’s value here is `0x1`, so this pointer arithmetic accesses our second number (`1`). Since `1` minus `2` does not equal zero, the jump is not taken. However, setting our second number to `2` would trigger the jump:
`1 2 1 1 1 1`

![Screenshot9](https://github.com/theokwebb/my-writeups/blob/main/BinaryBomb/Images/Screenshot9.png)

If you read through the next few instructions, it becomes apparent that we are in a loop, and to break free from it, we must take the `JGE` mentioned earlier:
```asm
cmp     dword ptr [rbp+4],6
jge     bomb!phase_2+0xa2 (00007ff7`fb952132)
```

If you cycle through the loop again, the comparison shifts from our second number to the third number. Consequently, our third number needs to match the second number after it is bit-shifted to the left (`4`):
```asm
| 0 1 0 0 |
| 8 4 2 1 |
```
You might have noticed a recurring pattern; we need to provide the decimal equivalent of the hexadecimal value to match the bit shift. For instance:
```asm
DEC: 1 2 4 8 16 32
HEX: 1 2 4 8 10 20
```
phase_2 complete!

![Screenshot10](https://github.com/theokwebb/my-writeups/blob/main/BinaryBomb/Images/Screenshot10.png)

# Phase 3
<a name="phase-3"></a>
If we step into `phase_3` and search for the initial call to `explode_bomb`, we can find a call to `sscanf`, and a `CMP` and `JGE`, reminiscent of `phase_2`. However, in this instance, a minimum of two inputs is required for the jump to occur:
```asm
cmp     dword ptr [rbp+64h], 2
```
If we look through the next instructions, we will find a `CMP` and `JA`, which compares our first input (located in `rbp+4`) to an immediate of `0x7`. If our input is above `0x7`, it will take the jump to `00007ff7fb95228a`. However, the address of this jump is for a call to `explode_bomb`. Therefore, our first input needs to be `7` or lower.

Next, there are several instructions and a jump to `RAX`. `RAX`’s address is calculated through some pointer arithmetic which includes our initial input in `RAX`:

![Screenshot11](https://github.com/theokwebb/my-writeups/blob/main/BinaryBomb/Images/Screenshot11.png)

So, my initial thought was to determine the number required to bypass all instances of `explode_bomb`. To achieve this, I subtracted `RCX`'s address (`0x7ff7fb940000`) from the target address I intended to jump to: `0x7ff7fb9522a2` (the instruction beyond the last `explode_bomb`, `LEA`), which resulted in `0x122A2`. I then used the command `dd rcx+x*4+122CCh L1` to assess the jump distance for each input, replacing `x` with our initial numerical input. For instance:

![Screenshot12](https://github.com/theokwebb/my-writeups/blob/main/BinaryBomb/Images/Screenshot12.png)

However, it becomes clear that due to the limitation of a maximum input value of `0x7`, we can’t jump as far as `0x122A2`. Our potential jump destinations align with the addresses listed below:

![Screenshot13](https://github.com/theokwebb/my-writeups/blob/main/BinaryBomb/Images/Screenshot13.png)

If our initial input were `1`, it would jump to `0x7FF7FB952245` (`0x7ff7fb940000` + `0x12245`). However, it’s unclear why we would want to jump to this address or any of the others. To shed some light on this, let’s search for the calls to `explode_bomb` and work backwards. Two calls to `explode_bomb` can be found, with the first one seemingly always being skipped, and the second with two potential triggers.

After the first call to `explode_bomb`, there is a `CMP` and `JG` sequence. This compares our first input (`rbp+4`) against `0x5`. If our input is exceeds `5`, it will result in a jump to `explode_bomb`. Therefore, our first input needs to be `5` or less.

Then, our second input (`rbp+24`) is moved into `EAX` and is subtracted from the value in `rbp+44`:
```asm
mov     eax,dword ptr [rbp+24h]
cmp     dword ptr [rbp+44h],eax
je      bomb!phase_3+0x112 (00007ff7`fb9522a2)
```
`rbp+44`’s value is derived from the various `mov`, `add`, and `sub` instructions we can jump to. If these two values are equal, it will bypass `explode_bomb`. Therefore, our second input needs to match the value obtained from those calculations. 

For example, if we input `2 2`, we jump to `7FF7FB952250` (calculated as `00012250` (`RAX`) + `7ff7fb940000` (`RCX`) = `7FF7FB952250`). By the jump at `7FF7FB952288`, `rbp+44h`’s value is `0x00000232` (`dd rbp+44 L1`). However, since our second input is `2`, it won’t match and will trigger `explode_bomb`. Therefore, inputting decimal `562` as our second parameter, which is `232` in hex, will match and result in the jump. It's important to note that entering `232` directly as the second parameter won't work, as it will be read as `0xE8` in decimal.

phase_3 complete!

![Screenshot14](https://github.com/theokwebb/my-writeups/blob/main/BinaryBomb/Images/Screenshot14.png)

It should also be noted that if our initial input is `0`, `1`, `2`, `3`, `4`, or `5`, and the second input matches the value stored in `rbp+44`, it will take the jump. For example, the input `1 4294967270` is also acceptable.

# Phase 4
<a name="phase-4"></a>
If we unassemble `phase_4` and skim over the instructions, we can find several important points: 

`sscanf` (much like `phase_3`) requires at least two user inputs to jump:
```asm
cmp     dword ptr [rbp+84h], 2
```

There are a series of jumps with the potential to trigger explode_bomb: `JNE` and `JL`. 

`JLE`, if taken, allows us to pass `explode_bomb`. Therefore, our first input (in `rbp+4`) needs to be less than or equal to `0xE` (DEC: `14`).

![Screenshot15](https://github.com/theokwebb/my-writeups/blob/main/BinaryBomb/Images/Screenshot15.png)

Next, an immediate of `0xA` is assigned to `rbp+64h`, and an unknown function `func4` is called with the parameters: `RCX` (our first input), `RDX` (`0x0`), `R8` (immediate of `0xE`), and `R9` (`0x1`).

Then, `CMP` subtracts `0xA` (immediate) from a value returned from `func4`, which was placed into `rbp+44h`. If they are *not* equal it jumps to `expode_bomb`. If they *are* equal, we move to another `CMP` with `JE`. This subtracts `0xA` from `rbp+24h`, which is our second input. Therefore, our second input needs to be the decimal equivalent of `0xA`: `10`.

Currently, we know that our first input needs to be less or equal to `0xE` (DEC: `14`), and our second input needs to be DEC `10`. 

Therefore, we need to step into `func4` in order to understand how we can make the return value become `0xA`:

![Screenshot16](https://github.com/theokwebb/my-writeups/blob/main/BinaryBomb/Images/Screenshot16.png)

As previously mentioned, `func4`’s parameters are: `RCX` (our first input), `RDX` (`0x0`), `R8` (`0xE`), and `R9` (`0x1`). They are saved to:
- `rbp+100h` = `0x3` (our input).
- `rbp+108h` = `0x0`.
- `rbp+110h` = `0xE`.

There’s a load of instructions before the first jump which may appear difficult to understand. However, the `sub`, `add`, and `CDQ` instructions all use `0x0` as an operand, so besides the result of the `SAR` instruction which is assigned to `rbp+4h`, there are no other significant modifications made.

`SAR` shifts `0xE` (`R8`) to the right: `0x7`. 

Then, there is a jump instruction:
```asm
cmp      dword ptr [rbp+4],eax
jle     bomb!func4+0x8a
```
Is “[`rbp+4` (`0x7`)] <= to `eax` (our input)”? If so, jump. 

It’s important to note that besides the `CMP`, all of the arithmetic performed is on values we can’t modify. Therefore, on `func4`’s first call, `rbp+4` will always equal `0x7` before the first jump.

So, let’s say our input is `0x1` and we skip the jump. This next series of instructions decrements `rbp+4` (`0x7`) by `1`, places it in `R8`, and calls `func4` again with the parameters:
`RCX` (our first input), `RDX` (`0x0`), `R8` (`0x6`), and `R9` (`0x1`).
Therefore, the only difference between the last `func4` call and this `func4` call is the third parameter `R8`.

The next instruction after the `func4` call adds the value stored in `rbp+4` (modified within `func4`) to `RAX`, and then exits `func4`. However, our input (located in `rbp+100h`) needs to align with the certain jump instructions; otherwise, we will call `func4` over and over again. 

So, we know the initial `func4` call assigns `0x7` to `rbp+4`, and our goal is for it to ultimately return `0xA`. Therefore, plus `0x3` more. Once `func4` is called again, it will right shift `0x7` to become `0x3`, which is exactly what we want (`0x7` + `0x3` = `0xA`). However, to prevent a repeated call to `func4`, we must ensure it takes the `JLE` path. Therefore, our input should be less than or equal to `0x3`.

This will take us to another jump:
```asm
cmp     dword ptr [rbp+4],eax
jge     bomb!func4+0xb5
```
Is “[`rbp+4` (`0x3`)] >= to `eax` (our input)”? If so, jump.

If we don’t take this jump, `func4` will be called once more. Therefore, in order to take this jump and the `JLE`, our input needs to be equal in both jump cases, and therefore set at `0x3`. 

`0x3` will be added to `0x7`, and returned to us with `0xA` and allow us to pass the phase:

![Screenshot17](https://github.com/theokwebb/my-writeups/blob/main/BinaryBomb/Images/Screenshot17.png)

# Phase 5
<a name="phase-5"></a>
If we unassemble `phase_5`, we can see that `phase_5`’s `sscanf` also requires at least two inputs in order to avoid `explode_bomb`.

So, we can also see our first input is assigned to `rbp+64h`, second input is assigned to `rbp+84h`, and the return value from `sscanf` (`0x2`) is assigned to `rbp+A4h`.

There is also a bitwise `AND` operation performed on our first input:
```asm
mov     eax,dword ptr [rbp+64h]
and     eax,0Fh
```
This operation sets all bits in `EAX` to `0` except for the four least significant bits. Therefore, our first input cannot exceed decimal `15` (`0x0F`) as the higher bits will be forced to be zero.

Next, an immediate of `0x0` is placed into `rbp+4` and `rbp+24`, and we come to another jump instruction:
```asm
cmp     dword ptr [rbp+64h],0Fh
je      bomb!phase_5+0xc4 (00007ff7`fb952524)
```
However, we can’t take this jump because if we do, it leads to another jump which compares two immediates `0x0` and `0x0F`, that cannot be equal if we take the first `je`, and thus leads us to an `explode_bomb`:
```asm
cmp     dword ptr [rbp+4],0Fh
jne     bomb!phase_5+0xd5 (00007ff7`fb952535)
```
Therefore, we need to skip the first `je`. This takes us to a series of instructions that puts us in a loop and increments `rbp+4` by `1` so that it can eventually be equal to `0x0F`, and we can jump to `00007ff7fb952535`. However, there is some pointer arithmetic that modifies the value of `rbp+64h` (our first input):
```asm
movsxd  rax,dword ptr [rbp+64h]
lea     rcx,[bomb!n1+0x20 (00007ff7`fb95f1d0)]
mov     eax,dword ptr [rcx+rax*4]
mov     dword ptr [rbp+64h],eax
```
If the value is modified to `0xF` *BEFORE* `rbp+4`’s value reaches `0xF`, it will break us out of this loop and `explode_bomb`. Therefore, with the command `dd 00007ff7fb95f1d0+X*4 L1`, let’s view the memory at each of the possible addresses:

![Screenshot18](https://github.com/theokwebb/my-writeups/blob/main/BinaryBomb/Images/Screenshot18.png)

`RAX` is equal to our first input (`rbp+64h`), so I just changed `X` to all the first possible inputs (`0x0`-`0xE`).

From this we can see that if the first number we input leads to a value of `6` *BEFORE* `rbp+4` equals `0xF`, it will break the loop. I.e., `rbp+64h` cannot be `6` or it will equal `F` on first loop and break the loop. `rbp+64h` cannot be `14` (`0xE`) or it will equal `F` on second loop, and so forth.

If you loop through each possible input above mentally, you will find that decimal `5` is able to loop until `0xF`:

Input of `5` = C --> 3 --> 7 --> B --> D --> 9 --> 4 --> 8 --> 0 --> A --> 1 --> 2 --> E --> 6 --> F 

`rbp+4` = `0xF` (`15` rotations)

You will also notice there is some more arithmetic performed on the immediate `0x0` in `rbp+24h` within the loop:
```asm
mov     ecx,dword ptr [rbp+24h]
add     ecx,eax
mov     eax,ecx
mov     dword ptr [rbp+24h],eax
```
This is important to consider because `rbp+24h`’s value will be compared against our second input in `rbp+84h`, and needs to be equal otherwise it jumps to an `explode_bomb`. These instructions basically increment `rbp+24h` by the value in `00007ff7fb95f1d0+X*4` each loop. Therefore, if we input `5` (`0xC`), by the end of the loop, `rbp+24h` will have a value of `0x73` (`C` + `3` + `7` + `B` + `D` + `9` + `4` + `8` + `0` + `A` + `1` + `2` + `E` + `6` + `F`). 

This means that our second input needs to be the decimal equivalent of hex `73`, so it is decimal `115`:

![Screenshot19](https://github.com/theokwebb/my-writeups/blob/main/BinaryBomb/Images/Screenshot19.png)

# Phase 6
<a name="phase-6"></a>
Firstly, there is a call to `read_six_numbers`, which as we already know, requires an input of six numbers. 

Next, there are a series of `CMP` instructions:
```asm
cmp     dword ptr [rbp+0C4h],6
jge     bomb!phase_6+0xee (00007ff7fb95269e)
```
Is “[`rbp+0C4h`] (0x0) `>=` to `6` (immediate)”? **No**.

```asm
cmp     dword ptr [rbp+rax*4+48h],1
jl      bomb!phase_6+0xa1 (00007ff7fb952651)
```
Is “[`rbp+rax*4+48h`]” (first input) `<` than `1` (immediate)”? 

If so, it jumps to `explode_bomb`. Therefore, our first input needs to be greater than `0x0`.

```asm
movsxd  rax,dword ptr [rbp+0C4h]
cmp     dword ptr [rbp+rax*4+48h],6
jle     bomb!phase_6+0xa6 (00007ff7fb952656)
```
Is “[`rbp+rax*4+48h`]” (first input) `<=` to `6` (immediate)”? 

If we skip this jump it calls `explode_bomb`. Therefore, our first input needs to be between `0x1`-`6`.

```asm
cmp     dword ptr [rbp+0E4h],6
jge     bomb!phase_6+0xec (00007ff7fb95269c)
```
Is “[`rbp+0E4h`] (`0x1`) `>=` to `6` (immediate)”? **No**.

```asm
movsxd  rax,dword ptr [rbp+0C4h]
movsxd  rcx,dword ptr [rbp+0E4h]
mov     ecx,dword ptr [rbp+rcx*4+48h]
cmp     dword ptr [rbp+rax*4+48h],ecx
jne     bomb!phase_6+0xea (00007ff7fb95269a)
```
Is “[`rbp+rax*4+48h`] (first input) `!=` to our second input”? 

If we skip this jump it calls `explode_bomb`, so our first input and second input can’t be equal.

![Screenshot20](https://github.com/theokwebb/my-writeups/blob/main/BinaryBomb/Images/Screenshot20.png)

Next, we enter a loop which increments `rbp+0E4h` by `0x1` each loop. It needs to loop `5` times in order for `rbp+0E4h`’s value to be equal to `0x6`, so we can take the `JGE` instruction to `00007ff7fb95269c` and break out of the loop. This will require our first input to *not be equal* to any other input. This is because in the `CMP`/`JNE` instructions it uses `rbp+0E4h` which is incremented by `0x1` each time to access our inputs. 

The next jump takes us right back to the start, which increments `rbp+0C4h` by `0x1`. So, we need to stay in this loop `6` times in order for the `JGE` instruction to jump to `00007ff7fb95269e` and break us out of the loop. However, there are several conditions for us to be able stay in this loop:

-	Each input needs to be greater than `0x0`.
-	Each input needs to be between `0x1`-`6`.
-	Each input cannot be equal to another. This is because the jump instructions use pointer arithmetic which includes `rbp+0C4h` and `rbp+0E4h`’s whose values are incremented in the loop.
Therefore, an input of say `6 5 4 3 2 1`, would allow us to break out of this loop.

Next, we come to some more `CMP` instructions:
```asm
cmp     dword ptr [rbp+0C4h],6
jge     bomb!phase_6+0x166 (00007ff7fb952716)
```
Is “[`rbp+0C4h`] (reset to `0x0`) `>=` to `6` (immediate)”? **No**.

`rbp+8` (`00007ff7fb95f050`) is moved into `RAX`, and `RAX` is moved into `rbp+28h`.

```asm
movsxd  rax,dword ptr [rbp+0C4h]
mov     eax,dword ptr [rbp+rax*4+48h]
cmp     dword ptr [rbp+0E4h],eax
jge     bomb!phase_6+0x154 (00007ff7fb952704)
```
Is “[`rbp+0E4h`] (reset to `0x1`) `>=` first input”?

If it is *not* `>=` `0x1`, we move `rbp+28h` (`00007ff7fb95f050`) into `RAX`, increment it by eight bytes to access `00007ff7fb95f040`’s memory, and store is back in `rbp+28h`. 

It will then enter a loop which will increment `rbp+0E4h` (`0x1`) by `0x1` *UNTIL* `rbp+0E4h` is `>=` to our first input.

*ONCE* `rbp+0E4h` is `>=` to our first input, it jumps to a series of instructions which saves the current `rbp+28h` value into memory at `rbp+rax*8+78h`:
```asm
movsxd  rax,dword ptr [rbp+0C4h]
rcx,qword ptr [rbp+28h]
mov     qword ptr [rbp+rax*8+78h],rcx
```

![Screenshot21](https://github.com/theokwebb/my-writeups/blob/main/BinaryBomb/Images/Screenshot21.png)

It then loops back around with a jump to `00007ff7fb9526aa` which increments `rbp+0C4h` (`0x0`) by `0x1`, and checks if `rbp+0E4h` is `>=` to our second input. It will continue to save `rbp+28h` value into memory at `rbp+rax*8+78h` *UNTIL* `rbp+0C4h` is incremented to `0x6`. 

It is important to note that if on the first loop, `rbp+0E4h` (`0x1`) was `>=` to our first input (of say `0x1`), it immediately saves `00007ff7fb95f050` to `rbp+rax*8+78h`’s memory. If, however, our input was `6`, we cycle through memory to save the lower address of `00007ff7fb95f000` to `rbp+rax*8+78h`’s memory. Therefore, we can assume `00007ff7fb95f050` corresponds to an input of `1`, `00007ff7fb95f040` an input of `2`, `00007ff7fb95f030` an input of `3`, `00007ff7fb95f020` an input of `4`, `00007ff7fb95f010` an input of `5`, and `00007ff7fb95f000` an input of `6`.

You also may have already noticed, but `7ff7fb95f050`, `7ff7fb95f040`, etc, are addresses, whose value can be viewed as follows:

![Screenshot22](https://github.com/theokwebb/my-writeups/blob/main/BinaryBomb/Images/Screenshot22.png)

As previously mentioned, we will eventually take the jump to `00007ff7fb952716`. At this point, I started to search for the exit condition for the phase and found two important details:

So, we need `rbp+0C4h` (reset to `0x1`) to be `>=` to `5` so we can jump to `00007ff7fb9527d1` and exit:
```asm
cmp     dword ptr [rbp+0C4h],5
jge     bomb!phase_6+0x221 (00007ff7`fb9527d1)
```

However, in order to do so, we need to take the jump to `00007ff7fb9527c3` on *EVERY* loop, so `rbp+0C4h` can reach `5`:
```asm
cmp     dword ptr [rcx],eax
jge     bomb!phase_6+0x213 (00007ff7fb9527c3)
```
Is “[`rcx`] `>=` [`eax`]”? 
In addition, if we don’t take this jump, it will call `explode_bomb`.

If we look at the instructions which precede the jump to `00007ff7fb9527c3`, we can see the values used in the `cmp` are from the addresses saved to `rbp+78h` and above. Specifically, the address in `RCX` used in the `cmp`, corresponds to the address saved at `rbp+78h`, and the address in `EAX` corresponds to the address saved at `rbp+78+8`, and both are incremented by eight bytes in each loop.  

As mentioned before, we control the addresses saved to `rbp+78h` and above. Therefore, we need the value at `rbp+78h`’s address to be `>=` than `rbp+78+8` address’s value in order to jump. In order words, the input that we select needs to correspond to a value which is always `>=` than the next value.

For example, if we review the values saved at each address, we can see `0x3a7` is the highest value:

![Screenshot22](https://github.com/theokwebb/my-writeups/blob/main/BinaryBomb/Images/Screenshot22.png)

`0x3a7` corresponds to address `7ff7fb95f010`, and as previously mentioned, `7ff7fb95f010` corresponds to an input of `5`. So, the next highest value is `0x393` at address `7ff7fb95f020`, which corresponds to an input of `4`, and so on:

- `0x3a7` --> `7ff7fb95f010` --> input `5`
- `0x393` --> `7ff7fb95f020` --> input `4`
- `0x215` --> `7ff7fb95f030` --> input `3`
- `0x212` --> `7ff7fb95f050` --> input `1`
- `0x200` --> `7ff7fb95f000` --> input `6`
- `0x1c2` --> `7ff7fb95f040` --> input `2`

Therefore, our input for `phase_6` is: `5 4 3 1 6 2`:

![Screenshot23](https://github.com/theokwebb/my-writeups/blob/main/BinaryBomb/Images/Screenshot23.png)

Bomb defused!

# Secret Phase
<a name="secretphase"></a>
In `phase_3` I stumbled across two unusual functions: `secret_phase` and `fun7`. Now, with the bomb defused, I thought I would try and find where those functions are called from. After *quite* some time, I found that `secret_phase` is called in the `phase_defused` function.

In `phase_defused`, it `CMP`’s the value of a variable named `num_input_strings` to `6`:
```asm
cmp     dword ptr [bomb!num_input_strings (00007ff7`fb95f8c4)],6
jne     bomb!phase_defused+0xcd (00007ff7`fb952d4d)
```
If we take the jump, it jumps past the call to `secret_phase`. Therefore, we need to avoid this jump.

If we do a little research, we will find in the `read_line` function called before each phase `num_input_strings`’s value is incremented by `0x1`:
```asm
mov     eax,dword ptr [bomb!num_input_strings (00007ff7`fb95f8c4)]
inc     eax
mov     dword ptr [bomb!num_input_strings (00007ff7`fb95f8c4)],eax
```
This means that we need to have passed `phase_6` in order to skip the `JNE`. 

In the next section of `phase_defused`, you can see there is another `JNE` which we need to skip in order call `secret_phase`:

![Screenshot24](https://github.com/theokwebb/my-writeups/blob/main/BinaryBomb/Images/Screenshot24.png)

```asm
call    bomb!ILT+705(sscanf) (00007ff7`fb9512c6)
mov     dword ptr [rbp+0B4h],eax
cmp     dword ptr [rbp+0B4h],3
jne     bomb!phase_defused+0xc1 (00007ff7`fb952d41)
```
Is the return value from `sscanf`  `!=` to `3`?

So, let’s take a look at `sscanf`’s parameters:

![Screenshot25](https://github.com/theokwebb/my-writeups/blob/main/BinaryBomb/Images/Screenshot25.png)

Our input for `phase_4` was `3 10`. `sscanf` reads this data from a buffer, following the format specification provided in the second parameter. In `phase_4`, the format specification is `%d %d`. However, the format specification here is `%d %d %s`.

According to the [sscanf](https://learn.microsoft.com/en-us/cpp/c-runtime-library/format-specification-fields-scanf-and-wscanf-functions?view=msvc-170) documentation, it states, "If a character in the input stream conflicts with the format specification, scanf terminates, and the character is left in the input stream as if it hadn't been read."

This implies that even if we provide input like `3 10 test` it won’t interfere with `phase_4`. Furthermore, if the same buffer is used in a call to `sscanf` with the format specification `%d %d %s` it will read and assign values accordingly.

In the next section of `phase_defused`, our string assigned from `sscanf` (`test`) is compared to another string in the `strings_not_equal` function:

![Screenshot26](https://github.com/theokwebb/my-writeups/blob/main/BinaryBomb/Images/Screenshot26.png)

![Screenshot27](https://github.com/theokwebb/my-writeups/blob/main/BinaryBomb/Images/Screenshot27.png)

It compares our input to the string `DrEvil`. So, let’s switch our input to that:

![Screenshot28](https://github.com/theokwebb/my-writeups/blob/main/BinaryBomb/Images/Screenshot28.png)

It appears we’re presented with another challenge, so let’s step into the `secret_phase`.

Here, we have a series of `CMP` instructions:
```asm
cmp     dword ptr [rbp+24h],1
jl      bomb!secret_phase+0x4f (00007ff7`fb9528df)
```
Is the value at [`rbp+24h`] (our input) less than `1`?
If so, *jump* to `explode_bomb`.

```asm
cmp     dword ptr [rbp+24h],3E9h
jle     bomb!secret_phase+0x54 (00007ff7`fb9528e4)
```
Is the value at [`rbp+24h`] (our input) less than or equal to `3E9` (DEC `1001`)”?
If so, *skip* `explode_bomb`.

It then calls an unknown function `fun7` with the parameters: `0x24` (`RCX`) and our input (`RDX`). `fun7`’s return value is stored in `rbp+44h` and compared to the immediate `0x5`. Therefore, need to somehow make the return value `0x5`:
```asm
call    bomb!ILT+35(fun7) (00007ff7`fb951028)
mov     dword ptr [rbp+44h],eax
cmp     dword ptr [rbp+44h],5
je      bomb!secret_phase+0x71 (00007ff7`fb952901)
```
So, let’s unassemble fun7. 

Here, we encounter several control flow instructions:
```asm
cmp     qword ptr [rbp+0E0h],0
jne     bomb!fun7+0x4b (00007ff7`fb951e7b)
```
Is the value at [`rbp+0E0h`] (`0x24`) *not* equal to `0`?

```asm
cmp     dword ptr [rbp+0E8h],eax
jge     bomb!fun7+0x78 (00007ff7`fb951ea8)
```
Is the value at [`rbp+0E8h`] (our input) *greater than or equal* to `0x24`?

If it is greater than or equal to `0x24`:
```asm
cmp     dword ptr [rbp+0E8h],eax
jne     bomb!fun7+0x8f (00007ff7`fb951ebf)
```
Is the value at [`rbp+0E8h`] (our input) not equal to `0x24`?

If our input is *equal* to `0x24`, it is zeroed and returned.

If our input is **greater** than `0x24`:
`fun7` is called again, but this time with the address of `rbp+0E0h` (`0x24`) incremented by `0x10`.

`rbp+0E0h` (`0000009027fdf8d0`) points to the memory location `00007ff7fb95f1b0`, where the value `0x24` is stored. `00007ff7fb95f1b0` incremented by `0x10` results in `00007ff7fb95f180`, where the value `0x32` is stored.

After the `fun7` call, the `LEA` (Load Effective Address) instruction effectively doubles the return value and adds `1` more, storing the result in `EAX`:
```asm
lea     eax,[rax+rax+1]
```

If our input is **less** than `0x24`:
`fun7` function is called again, but this time with the address of `rbp+0E0h` (`0x24`) incremented by `0x8`. `00007ff7fb95f1b0` incremented by `0x8` results in `00007ff7fb95f198`, which holds the value `0x8`.

After the `fun7` call, a `SHL` (Shift Logical Left) operation shifts the return value by `1` bit, and we exit the function. 

In essence, `fun7` is a recursive function that as part of its execution, invokes itself, and the direction it takes depends on whether our input is greater than or equal to `rbp+0E8h`. To understand all the possible paths, I manually traced through the various addresses in WinDBG to find their associated values:

```asm
00007ff7`fb95f1b0 (0x24)  INC by 0x10 = 0x32
                          INC by 0x8 = 0x8

00007ff7`fb95f180 (0x32)  INC by 0x10 = 0x6b
                          INC by 0x8 = 0x2d

00007ff7`fb95f198 (0x8)   INC by 0x10 = 0x16
                          INC by 0x8 = 0x6

00007ff7`fb95f168 (0x16)  INC by 0x10 = 0x23 (0x0 value beyond)
                          INC by 0x8 = 0x14 (0x0 value beyond)

00007ff7`fb95f168 (0x6)   INC by 0x10 = 0x7 (0x0 value beyond)
                          INC by 0x8 = 0x1 (0x0 value beyond)

00007ff7`fb95f168 (0x6b)  INC by 0x10 = 0x3e9 (0x0 value beyond)
                          INC by 0x8 = 0x63 (0x0 value beyond)

00007ff7`fb95f168 (0x2d)  INC by 0x10 = 0x2f (0x0 value beyond)
                          INC by 0x8 = 0x28 (0x0 value beyond)
```
So, for example, by incrementing `00007ff7fb95f1b0` by `0x10`, the offset address (`00007ff7fb95f180`) holds the value `0x32`. If we increment `0x32`’s address by `0x8`, the offset address (`00007ff7fb95f168`) holds the value `0x2d`, and so on. It is clear that many potential paths exist.

Now, the key part to this lies in the instructions *after* the `fun7` call and how the stack operates. Consider if we input `0x28` (DEC `40`), a value found at one of the possible addresses, and note the specific path it takes:
* Since `0x28` `>` `0x24`, `rbp+0E0h`'s address is incremented by `0x10`, making its value `0x32`.
* Since `0x28` `<` `0x32`, `rbp+0E0h`'s address is incremented by `0x8`, making its value `0x2d`.
* Since `0x28` `<` `0x2d`, `rbp+0E0h`'s address is incremented by `0x8`, making its value `0x28`.
* Since `0x28` matches `0x28`, it is zeroed and returned.

Once it returns `0x0` to the preceding `fun7` function call, the previous function call resumes and executes its next instruction. In the case of `0x8`, it shifts the return value `0x0`, to the left by `1` bit, and then exits the function. However, other function calls sit on the stack, so we pick up where we left off with the other function call, which also shifts the return value `0x0`, to the left by `1` bit and exits the function. In the next active frame on the stack, where we previously incremented by `0x10`, the return value (still `0x0`) is doubled, `0x1` is added, and then the frame is popped off the stack. Finally, with the stack empty, we return to `secret_phase` with `0x1`. This demonstrates how the `SHL` and `LEA` instructions, coupled with the right input, can eventually lead to a return value of `0x5`. This is the power of recursion. 

So, which path should we take? Our input must eventually match one of the possible values in the `INC` `0x10`/`0x8` paths in order to be zeroed; otherwise, we will skip the first `JNE` in `fun7` and move `0FFFFFFFFh` into `EAX`, resulting in a return value greater than `5`. Additionally, the next call requires increasing `0x0` to `0x1` with the `LEA` instruction, as `SHL` will have no effect on `0x0`. Therefore, we could shift `0x1` to `0x2` with `SHL`, and use `LEA` to double `0x2` and increment it by `0x1`, in order to achieve a final return value of `0x5`.

Here is the exact path:
* Input needs to be `>` than `0x24` (`INC 0x10`).
* Input needs to be `<` than `0x32` (`INC 0x8`).
* Input needs to match `0x2F` (DEC `47`) (`INC 0x10`).

This guarantees a return value of `0x5` to successfully defuse the secret phase.

![Screenshot29](https://github.com/theokwebb/my-writeups/blob/main/BinaryBomb/Images/Screenshot29.png)

#

Thank you to Bryant & O'Hallaron at [Carnegie Mellon University]( http://csapp.cs.cmu.edu/3e/home.html) for this enjoyable lab and Xeno at [OpenSecurityTraining2](https://ost2.fyi) for the incredible [Architecture 1001: x86-64 Assembly](https://ost2.fyi/Arch1001) course.

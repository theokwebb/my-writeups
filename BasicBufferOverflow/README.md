# OST2 Arch1001: Basic Buffer Overflow Lab

## Challenge Description

In this lab, our objective is to provide an input that triggers the execution of the `AwesomeSauce()` function within the `BasicBufferOverflow.c` program.

## Easy-mode: Debug-Build

To start, let's delve into the source code:

```C
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int lame(__int64 value) {
	__int64 array1[8];
	__int64 array2[8];
	array2[0] = array2[1] = array2[2] = array2[3] = value;
	memcpy(&array1, &array2, 8 * sizeof(__int64));
	return 1;
}

int lame2(__int64 size, __int64 value) {
	__int64 array1[6];
	__int64 array2[6];
	array2[0] = array2[1] = array2[2] = array2[3] = array2[4] = array2[5] = value;
	memcpy(&array1, &array2, size * sizeof(__int64));
	return 1;
}

void AwesomeSauce() {
	printf("Awwwwwww yeaaahhhhh! All awesome, all the time!\n");
}

int main(unsigned int argc, char** argv) {
	__int64 size, value;
	size = _strtoi64(argv[1], "", 10);
	value = _strtoi64(argv[2], "", 16);

	if (!lame(value) || !lame2(size, value)) {
		AwesomeSauce();
	}
	else {
		printf("I am soooo lame :(\n");
	}

	return 0xdeadbeef;
}
```
So, we can observe that in the `main()` function, `argv` is of type `char**`, meaning it's a pointer to an array of pointers to characters, essentially representing an array of strings.

Our initial two inputs, `argv[1]` and `argv[2]`, are placed into this array. However, before so, they are first converted to an `__int64` value (64-bit integer) with the `_strtoi64` function.

As stated in [_strtoi64](https://learn.microsoft.com/en-us/cpp/c-runtime-library/reference/strtoi64-wcstoi64-strtoi64-l-wcstoi64-l?view=msvc-170)’s documentation, the third parameter is the number base to use. Therefore, our first input is in decimal while the second is in hexadecimal.

Next, `lame` and `lame2` functions are called. If they return `0`, `AwesomeSauce()` will be called. However, it’s evident that both `lame` and `lame2` will *always* return `1`, so we need a different approach. 

`lame` and `lame2` are quite similar; they both assign our second input to all elements of the array `array2` and utilize `memcpy()` to copy `n` bytes from memory `array2` to `array1`. However, in the `lame` function, there are eight elements, whereas in `lame2`'s function, there are six. Additionally, in the `lame` function, our second input is assigned to elements `3`, `2`, `1`, and `0`, while in `lame2`'s function, it is assigned to `5`, `4`, `3`, `2`, `1`, and `0`. Moreover, in `lame2`'s function, our first input acts as the factor in:
```C
memcpy(&array1, &array2, size * sizeof(__int64));
```
while `lame`'s factor is fixed at `8`. This is incredibly dangerous because it allows us to control how many bytes are copied from `array2` to `array1` in `memcpy()`.

To make this easier to understand, let’s visualize this with a stack diagram:

Input of `6 deadbeef`:

```
|                   |
|                   |
|     Main()        | 0x48 bytes
|     Frame         |
|                   |
|-------------------|
|                   |
|     Lame2()       | 0x88 bytes
|     Frame         |
|-------------------|
| 0x00000001400011fe| <- return address (to main)
|-------------------|
|                   |
| 16-byte padding   | 0x000000000014FDC0
|-------------------|
| array1[5]         | 0x000000000014FDB8
|-------------------|
| array1[4]         | 0x000000000014FDB0
|-------------------|
| array1[3]         | 0x000000000014FDA8
|-------------------|
| array1[2]         | 0x000000000014FDA0
|-------------------|
| array1[1]         | 0x000000000014FD98
|-------------------|
| array1[0]         | 0x000000000014FD90
|-------------------|
| array2[5]         | 0x000000000014FD88
|-------------------|
| array2[4]         | 0x000000000014FD80
|-------------------|
| array2[3]         | 0x000000000014FD78
|-------------------|
| array2[2]         | 0x000000000014FD70
|-------------------|
| array2[1]         | 0x000000000014FD68
|-------------------|
| array2[0]         | 0x000000000014FD60
|-------------------|
| undefined data    | 0x000000000014FD58
|-------------------|
| undefined data    | 0x000000000014FD50
|-------------------|
| undefined data    | 0x000000000014FD48
|-------------------|
| undefined data    | 0x000000000014FD40
|-------------------|
|                   |
```
First, during the `CALL` to `lame2()`, the next assembly instruction (`0x00000001400011fe`) is stored on the stack, allowing us to return to `main()` later.

Then, there's a 16-byte stack alignment padding, followed by our second input being assigned to elements `0-5` for both `array1` and `array2`.

After the call to `memcpy()`, the stack appears as follows:

![Screenshot1](https://github.com/theokwebb/my-writeups/blob/main/BasicBufferOverflow/Images/Screenshot1.png)

Currently, `memcpy()` copies `48 bytes` (`6` elements * `sizeof(__int64)` = `6` * `8` bytes) from `array2` to `array1`. However, if we adjust our input to `8`, it will copy `64` bytes, causing `array2` to overflow into the alignment padding and overwrite the return address (`0x00000001400011fe`) with `0xdeadbeef`. Thus, when the `RET` instruction executes at the end of `lame2()`, program control will be transferred to the address `0xdeadbeef`:

![Screenshot2](https://github.com/theokwebb/my-writeups/blob/main/BasicBufferOverflow/Images/Screenshot2.png)

![Screenshot3](https://github.com/theokwebb/my-writeups/blob/main/BasicBufferOverflow/Images/Screenshot3.png)

Obviously, there is no actual memory location of `0xdeadbeef`. However, if we scroll through the disassembly to find the initial instruction within the `AwesomeSauce()` function, we can use that address as our second input. Then, with the `RET` instruction, we can effectively jump to that specific address, which will execute the code within the `AwesomeSauce()` function.

Input of `8 140001160`:

![Screenshot4](https://github.com/theokwebb/my-writeups/blob/main/BasicBufferOverflow/Images/Screenshot4.png)

As always, thank you to Xeno at [OpenSecurityTraining2](https://ost2.fyi) for this lab and incredible course.

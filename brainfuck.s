.bss
cells: .zero	2400000
code: .zero	100000
stack: .zero	40000
.comm	input,8,8

.data
i: .long	2300

readonly: .string	"r"

.text
.globl	main
main:
	pushq	%r15
	pushq	%r14
	pushq	%r13	# file size
	pushq	%r12	# file buffer
	pushq	%rbx
	
	cmpq	$2, %rdi #check that we have 2 args
	je	argspresent	#

	movq	$2, %rdi	# exit(2)
	call	exit

argspresent:
	movq	%rsi, %rdi
	movq	8(%rdi), %rdi # argv[1]
	movq	$readonly, %rsi
	call	fopen
	movq	%rax, %r12	# r12 = file

	cmpq	$0, %r12	# check if file exists
	jne		fileopened
	
	movq	$1, %rdi	# exit (1)
	call	exit
	
fileopened:
	movq	%r12, %rdi
	movq	$2, %rdx
	movq	$0, %rsi
	call	fseek	# fseek(file, 0, end)

	movq	%r12, %rdi
	call	ftell
	movq	%rax, %r13	# r13 = filesize

	movq	%r12, %rdi
	call	rewind	# rewind file

	movq	%r13, %rdi
	call	malloc	# allocate filezise bytes for file
	
	movq	%rax, input	# move file to input variable

	movq	%r13, %rsi	#filesize
	movq	input, %rdi
	movq	%r12, %rcx #file
	movq	$1, %rdx	#sizeof(char)
	call	fread

	movq	%r12, %rdi
	call	fclose	#close file
	
	movq	$0, %rdi	# count
	movq	$0, %rbx	# currentinstructionpointer
	movq	$0, %r12	#char_buffer
	movq	$0, %r13	# bfpointer
	movq	$0, %r14	# count2
	movq	$0, %r15	# nestcounter
whileloop:
	movq	input, %rax
	addq	%rdi, %rax	# offset input by count
	movb	(%rax), %r12b	#move input[count] char into charbuffer
	addq	$1, %rdi	# count++

	testb	%r12b, %r12b	# if charbuffer == 0
	je		breakloop
	cmpb	$91, %r12b	# if charbuffer != '['
	jne		checkclosenest	#

	leaq	(,%r15,4), %rdx # nestcounter address
	leaq	stack, %rax
	movq	%rbx, (%rdx,%rax)	# stack[nestcounter] = currentinstructionpointer
	
	addq	$1, %r15	# nestcounter++
	leaq	code, %rax
	movq	%r12, (%r14,%rax)	# code[count2] = charbuffer
	addq	$5, %r14	# count2 += (sizeof(currentinstructionpointer) + 1)
	addq	$5, %rbx	# currentinstructionpointer += 5 (same as above)
	jmp		continue

checkclosenest:
	cmpq	$93, %r12	# if charbuffer != ']'
	jne		nextinstruction

	subq	$1, %r15	# nestcounter--
	leaq	1(%r14), %rdx	# count2
	leaq	code, %rax	
	addq	%rax, %rdx	# code+count2+1
	movq	%r15, %rax	# nestcounter
	leaq	(,%rax,4), %rcx	# code+count2+5
	leaq	stack, %rax
	movq	(%rcx,%rax), %rax	# stack[*code+count2+sizeof(char)+1]
	movq	%rax, (%rdx) #*(typeof(currentinstructionpointer) *)(code+count2*sizeof(char)+1) = stack[nestcounter];
	
	movq	%r14, %rdx	# count2
	leaq	code, %rax
	movb	%r12b, (%rdx,%rax)	# code[count2] = charbuffer
	addq	$5, %r14	# count2 += 5
	movq	%r15, %rax	# nestcounter
	leaq	(,%rax,4), %rdx
	leaq	stack, %rax
	movl	(%rdx,%rax), %eax	#stack[nestcounter]
	leaq	1(%rax), %rdx	#stack[nestcounter]++
	leaq	code, %rax
	addq	%rdx, %rax	#code+stack[nestcounter]
	movl	%ebx, (%rax)	# *(typeof(currentinstructionpointer) *)(code+stack[nestcounter]*sizeof(char)+1) = currentinstructionpointer;
	addq	$5, %rbx	# currentinstructionpointer += 5
	jmp		continue
nextinstruction:
	movq	%r14, %rdx	# count2
	leaq	code, %rax
	movb	%r12b, (%rdx,%rax)	#code[count2] = char_buffer
	addq	$1, %r14	# count2++
	addq	$1, %rbx	# currentinstructionpointer++
continue:
	jmp	whileloop
breakloop:
	nop

parsecodeinit:
	movq	$0, i	# i = 0
	movq	$0, %rbx	# currentinstructionpointer = 0
parseswitch:
	movq	%rbx, %rdx	# currentinstructionpointer
	leaq	code, %rax
	movzbq	(%rdx,%rax), %rax	# code[currentinstructionpointer]
	cmpq	$43, %rax
	je	plus
	cmpq	$44, %rax
	je	comma
	cmpq	$45, %rax
	je	minus
	cmpq	$46, %rax
	je	dot
	cmpq	$60, %rax
	je	lessthan
	cmpq	$62, %rax
	je	morethan
	cmpq	$91, %rax
	je	nestopen
	cmpq	$93, %rax
	je	nestclose
	testq	%rax, %rax	# if we're done parsing
	je	end
	jmp	parsenextinstruction
	

morethan:
	leaq	1(%r13), %r13	# bfpointer++
	jmp	parsenextinstruction
lessthan:
	leaq	-1(%r13), %r13	# bfpointer
	jmp	parsenextinstruction
plus:
	movq	%r13, %rax	# bfpointer
	movq	%rax, %rdx
	leaq	(,%rdx,8), %rcx
	leaq	cells, %rdx
	movq	(%rcx,%rdx), %rdx	# cells[bfpointer]
	leaq	1(%rdx), %rcx	#cells[bfpointer]++
	leaq	(,%rax,8), %rdx
	leaq	cells, %rax
	movq	%rcx, (%rdx,%rax)	# cells[bfpointer] = cells[bfpointer]+1
	jmp	parsenextinstruction
minus:
	movq	%r13, %rax	# bfpointer
	movq	%rax, %rdx
	leaq	(,%rdx,8), %rcx
	leaq	cells, %rdx
	movq	(%rcx,%rdx), %rdx	# cells[bfpointer]
	leaq	-1(%rdx), %rcx	#cells[bfpointer]++
	leaq	(,%rax,8), %rdx
	leaq	cells, %rax
	movq	%rcx, (%rdx,%rax)	# cells[bfpointer] = cells[bfpointer]+1
	jmp	parsenextinstruction
dot:
	movq	%r13, %rax	# bfpointer
	leaq	(,%rax,8), %rdx
	leaq	cells, %rax
	addq	%rdx, %rax #cells[bfpointer]
	movq	$1, %rdx
	movq	%rax, %rsi
	movq	$1, %rdi
	call	write #write 1 character into cells[bfpointer]
	jmp	parsenextinstruction	#
comma:
	movq	%r13, %rax	# bfpointer, _33
	leaq	(,%rax,8), %rdx
	leaq	cells, %rax
	addq	%rdx, %rax #cells[bfpointer]
	movq	$1, %rdx
	movq	%rax, %rsi
	movq	$0, %rdi
	call	read #read 1 character into cells[bfpointer]
	jmp	parsenextinstruction

nestopen:
	movq	%r13, %rax	# bfpointer
	leaq	(,%rax,8), %rdx
	leaq	cells, %rax
	movq	(%rdx,%rax), %rax	# cells[bfpointer]
	testq	%rax, %rax
	jne	nestopencont	#if cells[bfpointer] != 0					
	movq	%rbx, %rax	# currentinstructionpointer
	leaq	1(%rax), %rdx	#currentinstructionpointer+1
	leaq	code, %rax
	addq	%rdx, %rax #code + currentinstructionpointer + 1
	movl	(%rax), %ebx	# currentinstructionpointer = *rax
nestopencont:
	addq	$5, %rbx	# currentinstructionpointer = *(typeof(currentinstructionpointer) *)(code+currentinstructionpointer*sizeof(char)+1);
	jmp	parseswitch

nestclose:
	movq	%r13, %rax	# bfpointer
	leaq	(,%rax,8), %rdx	
	leaq	cells, %rax
	movq	(%rdx,%rax), %rax	# cells[bfpointer]
	testq	%rax, %rax	#if cells[bfpointer] == 0
	je	nestclosecont
	movq	%rbx, %rax	# currentinstructionpointer
	leaq	1(%rax), %rdx	#currentinstructionpointer+1
	leaq	code, %rax
	addq	%rdx, %rax	#code+currentinstructionpointer+1
	movl	(%rax), %ebx	#currentinstructionpointer = *(typeof(currentinstructionpointer) *)(code+currentinstructionpointer*sizeof(char)+1);
nestclosecont:
	addq	$5, %rbx	# currentinstructionpointer++
	jmp	parseswitch
parsenextinstruction:
	addq	$1, %rbx	# currentinstructionpointer++
	jmp	parseswitch
end:
	movq	$0, %rax
	popq	%rbx
	popq	%r12
	popq	%r13
	popq	%r14
	popq	%r15
	popq	%rbp
	call	exit
